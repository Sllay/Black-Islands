class_name CombatDummy
extends CharacterBody3D
## QA-only recipient, not NPC AI; never deals automatic overlap damage.
@export var defense := 50.0
@export var max_health := 400.0
var health := 400.0
var hits := 0
var last_damage := 0.0
var last_instance := 0
var _reaction := 0.0
@onready var label: Label3D = $Label
@onready var mesh: MeshInstance3D = $Mesh

func _ready() -> void:
	add_to_group("combat_targets")
	health = max_health
	_refresh()

func _physics_process(delta: float) -> void:
	velocity.x = move_toward(velocity.x,0,12*delta)
	velocity.z = move_toward(velocity.z,0,12*delta)
	velocity.y = -0.2 if is_on_floor() else velocity.y-18*delta
	move_and_slide()
	if _reaction > 0:
		_reaction = maxf(0.0,_reaction-delta)
		mesh.scale = Vector3(1.05,0.94,1.05) if _reaction > 0 else Vector3.ONE

func receive_hit(hit: HitPayload) -> float:
	if health <= 0:
		return 0.0
	last_damage = DamageFormula.taken(hit.raw_damage,defense)
	health = maxf(0,health-last_damage)
	velocity += hit.impulse
	hits += 1
	last_instance = hit.attack_instance
	_reaction = 0.18
	_refresh()
	return last_damage

func reset() -> void:
	health = max_health
	hits = 0
	_refresh()

func pulse_player(player: PlayerActor) -> float:
	# An explicit QA command; native volume validates range, not contact damage.
	var shape := SphereShape3D.new()
	shape.radius = 2.5
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 2
	query.transform.origin = global_position+Vector3.UP*0.8
	for body: Dictionary in get_world_3d().direct_space_state.intersect_shape(query):
		if body.collider == player:
			var hit := HitPayload.new()
			hit.raw_damage = 12
			hit.impulse = (player.global_position-global_position).normalized()*2
			hit.attack_id = "qa.dummy.pulse"
			return player.combat.receive_hit(hit)
	return 0

func _refresh() -> void:
	label.text = "QA • ALVO\n%d / %d  DEF %d\n%d hits • %.1f dano" % [health,max_health,defense,hits,last_damage]
