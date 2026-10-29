extends Node3D
## Native hit volumes plus deterministic controller clocks; no giant test framework.
var failures := 0
var player: PlayerActor
var dummy: CombatDummy
const DT := 1.0/60.0

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("P03_C03 FAIL " + label)

func _step(axis := Vector2.ZERO, press := false, release := false, dodge_press := false) -> void:
	player.combat.tick(DT,axis,press,release,dodge_press)
	player.motor.movement_locked = player.combat.movement_locked()
	player.motor.tick(DT,axis,false)

func _ticks(count: int, axis := Vector2.ZERO) -> void:
	for frame: int in range(count):
		_step(axis)

func _run() -> void:
	var arena: Node3D = load("res://tests/integration/PlayerC01Smoke.tscn").instantiate()
	arena.set_script(null)
	add_child(arena)
	player = load("res://scenes/player/Player.tscn").instantiate()
	player.position = Vector3(0,0.05,0)
	add_child(player)
	dummy = load("res://scenes/debug/CombatDummy.tscn").instantiate()
	dummy.position = Vector3(0,0.05,-1.6)
	add_child(dummy)
	for frame: int in range(12):
		await get_tree().physics_frame
	player.set_physics_process(false)
	dummy.set_physics_process(false)
	var moveset := player.combat.moveset
	_check(moveset != null and moveset.attacks.size() == 4, "data-driven sword resources")
	_check(moveset.resolve("sword.light.1","LIGHT").id == "sword.light.2" and moveset.resolve("sword.light.2","HEAVY").id == "sword.heavy.1", "combo graph L/L/H seam")
	_step(Vector2.ZERO,true)
	_ticks(22)
	var position_before := player.global_position
	_ticks(30,Vector2(1,0))
	_check(player.combat.phase == PlayerCombat.Phase.HEAVY_AIM and player.combat.attacks_started == 0 and dummy.hits == 0, "hold -> zero attacks")
	_check(player.combat.indicator.global_position.is_equal_approx(player.global_position), "aim geometry inherits player world transform")
	_check(player.global_position.distance_to(position_before) < 0.05 and player.combat.aim.dot(Vector3.RIGHT) > 0.99, "HeavyAim joystick aims instead of locomotion")
	_step(Vector2(0,-1))
	_step(Vector2(0,-1),false,true)
	_check(player.combat.attacks_started == 1, "release -> exactly one attack")
	_step(Vector2.ZERO,false,true)
	_ticks(75)
	_check(player.combat.attacks_started == 1 and dummy.hits == 1 and is_equal_approx(dummy.last_damage,28.0), "native heavy hitbox once per target, defense50")
	_check(dummy.velocity.length() > 0 and dummy._reaction > 0, "knockback / reaction hooks")
	var instance := AttackInstance.new()
	instance.begin(moveset.attacks[0])
	_check(instance.accept(dummy,0.1) and not instance.accept(dummy,0.2), "AttackInstance rejects repeated target")
	for defense: float in [0.0,50.0,100.0,200.0]:
		_check(is_equal_approx(DamageFormula.taken(100,defense),10000.0/(100.0+defense)), "defense formula " + str(defense))
	_check(player.combat.dodge.invulnerable(0.045) and not player.combat.dodge.invulnerable(0.04499) and not player.combat.dodge.invulnerable(0.22), "deterministic half-open i-frame window")
	player.combat.cancel()
	player.state.set_stamina(100)
	_step(Vector2.RIGHT,false,false,true)
	_check(player.combat.dodges == 1 and is_equal_approx(player.state.current_stamina,76), "dodge stamina cost")
	_step(Vector2.RIGHT,false,false,true)
	_ticks(3)
	_check(player.combat.dodges == 1 and player.combat.invulnerable() and player.motor.burst_velocity.x > 10, "dodge burst, no spam")
	var hit := HitPayload.new()
	hit.raw_damage = 20
	_check(player.combat.receive_hit(hit) == 0 and player.state.current_health == 100, "player i-frame blocks valid incoming hit")
	_ticks(12)
	_check(not player.combat.invulnerable() and player.combat.receive_hit(hit) == 20 and player.state.current_health == 80, "i-frame ends, incoming damage works")
	_ticks(35)
	player.state.set_stamina(0)
	_step(Vector2.RIGHT,false,false,true)
	_check(player.combat.dodges == 1, "insufficient stamina blocks dodge")
	player.state.set_stamina(100)
	player.combat.cancel()
	var attack_count := player.combat.attacks_started
	_step(Vector2.ZERO,true)
	_step(Vector2.ZERO,false,true)
	_check(player.combat.attacks_started == attack_count+1 and player.combat.report().combo == "sword.light.1", "light tap")
	_ticks(20)
	_step(Vector2.ZERO,true)
	_step(Vector2.ZERO,false,true)
	_ticks(15)
	_check(player.combat.attacks_started == attack_count+2 and player.combat.report().combo == "sword.light.2", "buffered L -> L transition")
	player.combat.receive_hit(hit)
	_ticks(60)
	_check(player.combat.report().buffer == "" and player.combat.report().combo == "", "hurt invalidates combo/buffer")
	player.combat.cancel()
	_step(Vector2.ZERO,true)
	_ticks(30)
	attack_count = player.combat.attacks_started
	player.inventory.state.select_hotbar(1)
	_step(Vector2.ZERO,false,true)
	_check(player.combat.attacks_started == attack_count and player.combat.report().moveset == "", "weapon swap cancels held attack, no stale release")
	print("P03_C03 ","PASS" if failures == 0 else "FAIL"," failures=",failures," combat=",player.combat.report())
	get_tree().quit(1 if failures else 0)
