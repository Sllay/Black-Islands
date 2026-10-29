class_name PlayerCombat
extends Node
## Local combat state machine. No direct clip names, item contents or aim rays.
signal attack_started(attack_id: String, instance: int)
signal hit_confirmed(target: Node3D, amount: float)
enum Phase { READY, PRESS_PENDING, HEAVY_AIM, ATTACK, DODGE, HURT, DEAD }
var phase := Phase.READY
var aim := Vector3.FORWARD
var attacks_started := 0
var hits := 0
var dodges := 0
var actor: PlayerActor
var moveset: MovesetDefinition
var dodge: DodgeDefinition
var _active_item := ""
var _elapsed := 0.0
var _clock := 0.0
var _held := false
var _hold_time := 0.0
var _buffer := ""
var _buffer_until := 0.0
var _combo_node := ""
var _combo_until := 0.0
var _hitstop := 0.0
var _dodge_direction := Vector3.FORWARD
var _instance := AttackInstance.new()
var _hit := HitPayload.new()
var _query := PhysicsShapeQueryParameters3D.new()
@onready var indicator: Node3D = $"../AimIndicator"

func configure(player: PlayerActor) -> void:
	actor = player
	dodge = CombatCatalog.dodge()
	_query.collision_mask = CollisionLayers.MOB
	_query.exclude = [actor.get_rid()]
	actor.inventory.state.changed.connect(func(_revision: int) -> void: _refresh_weapon())
	_refresh_weapon()

func _refresh_weapon() -> void:
	var definition := actor.inventory.state.active_definition()
	var id := definition.id if definition != null else ""
	if id == _active_item:
		return
	_active_item = id
	moveset = CombatCatalog.moveset(definition.moveset_id) if definition != null else null
	cancel()

func cancel() -> void:
	phase = Phase.DEAD if actor != null and actor.state.current_health <= 0 else Phase.READY
	_held = false
	_buffer = ""
	_combo_node = ""
	_elapsed = 0.0
	_hitstop = 0.0
	if actor != null:
		actor.motor.burst_velocity = Vector3.ZERO
	indicator.visible = false

func tick(delta: float, axis: Vector2, pressed: bool, released: bool, dodge_pressed: bool) -> void:
	_clock += delta
	if actor.inventory.is_open or not actor.spawned:
		cancel()
		return
	if phase == Phase.DEAD:
		return
	if _clock > _combo_until:
		_combo_node = ""
	if _clock > _buffer_until:
		_buffer = ""
	if pressed and moveset != null and phase not in [Phase.DODGE,Phase.HURT]:
		_held = true
		_hold_time = 0.0
		if phase == Phase.READY:
			phase = Phase.PRESS_PENDING
			aim = actor.motor.facing
	if _held:
		_hold_time += delta
	if phase == Phase.PRESS_PENDING and _held and _hold_time >= moveset.hold_threshold:
		phase = Phase.HEAVY_AIM
		actor.velocity.x = 0
		actor.velocity.z = 0
	if phase == Phase.HEAVY_AIM:
		var direction := actor.camera_rig.planar_direction(axis)
		if direction.length_squared() > 0.04:
			aim = direction.normalized()
		else:
			aim = aim.normalized() if not aim.is_zero_approx() else actor.motor.facing
		actor.motor.facing = aim
		indicator.visible = true
		indicator.rotation.y = atan2(-aim.x, -aim.z)
	if released and _held:
		var input := "HEAVY" if _hold_time >= moveset.hold_threshold else "LIGHT"
		_held = false
		if phase in [Phase.PRESS_PENDING,Phase.HEAVY_AIM]:
			_request_attack(input)
		elif phase == Phase.ATTACK and _elapsed >= _instance.definition.duration() - moveset.buffer_window:
			_buffer = input
			_buffer_until = _clock + moveset.buffer_window
	if dodge_pressed and phase in [Phase.READY,Phase.PRESS_PENDING]:
		_begin_dodge(axis)
	if _hitstop > 0:
		_hitstop = maxf(0.0,_hitstop-delta)
		return
	var previous := _elapsed
	_elapsed += delta
	if phase == Phase.ATTACK:
		var attack := _instance.definition
		if _elapsed >= attack.windup and previous < attack.windup + attack.active_duration:
			_hit_volume()
		if _elapsed >= attack.duration():
			phase = Phase.READY
			if not _buffer.is_empty():
				var input := _buffer
				_buffer = ""
				_request_attack(input)
			elif _held:
				phase = Phase.PRESS_PENDING
	elif phase == Phase.DODGE:
		actor.motor.burst_velocity = _dodge_direction*dodge.burst_speed if _elapsed < dodge.burst_seconds else Vector3.ZERO
		if _elapsed >= dodge.duration:
			phase = Phase.READY
	elif phase == Phase.HURT and _elapsed >= 0.25:
		phase = Phase.READY
	indicator.visible = phase == Phase.HEAVY_AIM

func _request_attack(input: String) -> void:
	indicator.visible = false
	var attack := moveset.resolve(_combo_node,input) if moveset != null else null
	if attack == null or not actor.state.consume(attack.stamina_cost):
		phase = Phase.READY
		return
	if phase != Phase.HEAVY_AIM:
		aim = actor.motor.facing
	phase = Phase.ATTACK
	_elapsed = 0.0
	_instance.begin(attack)
	_combo_node = attack.id
	_combo_until = _clock + attack.duration() + moveset.combo_timeout
	_query.shape = attack.shape
	actor.visual.play_semantic(attack.semantic_action,attack.duration())
	attacks_started += 1
	attack_started.emit(attack.id,_instance.sequence)

func _hit_volume() -> void:
	var basis := Basis.looking_at(aim,Vector3.UP)
	_query.transform = Transform3D(basis,actor.global_position+basis*_instance.definition.offset)
	var results := actor.get_world_3d().direct_space_state.intersect_shape(_query,16)
	for result: Dictionary in results:
		var target := result.collider as Node3D
		if target == null or not target.is_in_group("combat_targets") or not target.has_method("receive_hit"):
			continue
		if not actor.targeter.has_line_of_sight(target.global_position) or not _instance.accept(target,_elapsed):
			continue
		_hit.raw_damage = _instance.definition.damage
		_hit.impulse = aim * _instance.definition.knockback
		_hit.hitstop = _instance.definition.hitstop
		_hit.attack_id = _instance.definition.id
		_hit.attack_instance = _instance.sequence
		var amount := float(target.receive_hit(_hit))
		if amount > 0:
			hits += 1
			_hitstop = _instance.definition.hitstop
			hit_confirmed.emit(target,amount)

func _begin_dodge(axis: Vector2) -> void:
	if not actor.state.consume(dodge.stamina_cost):
		return
	_held = false
	_buffer = ""
	_combo_node = ""
	phase = Phase.DODGE
	_elapsed = 0.0
	_dodge_direction = actor.camera_rig.planar_direction(axis).normalized() if axis.length_squared() > 0.04 else actor.motor.facing
	actor.motor.facing = _dodge_direction
	actor.motor.burst_velocity = _dodge_direction * dodge.burst_speed
	actor.visual.play_semantic(LPCActionResolver.DODGE,dodge.duration)
	dodges += 1

func movement_locked() -> bool:
	return phase in [Phase.HEAVY_AIM,Phase.ATTACK,Phase.DODGE,Phase.HURT,Phase.DEAD] or _hitstop > 0

func hitstopped() -> bool:
	return _hitstop > 0

func invulnerable() -> bool:
	return phase == Phase.DODGE and dodge.invulnerable(_elapsed)

func receive_hit(hit: HitPayload) -> float:
	if invulnerable() or phase == Phase.DEAD:
		return 0.0
	var amount := DamageFormula.taken(hit.raw_damage,actor.state.defense+actor.inventory.state.equipment_defense())
	if amount <= 0:
		return 0.0
	actor.state.set_health(actor.state.current_health-amount)
	cancel()
	phase = Phase.HURT if actor.state.current_health > 0 else Phase.DEAD
	_hitstop = hit.hitstop
	actor.motor.external_impulse += hit.impulse
	actor.visual.play_semantic(LPCActionResolver.HURT,0.25)
	return amount

func report() -> Dictionary:
	return {"phase":Phase.keys()[phase], "attacks":attacks_started, "hits":hits, "dodges":dodges,
		"elapsed":_elapsed, "invulnerable":invulnerable(), "aim":aim, "combo":_combo_node,
		"buffer":_buffer, "moveset":moveset.id if moveset != null else "", "instance":_instance.sequence}
