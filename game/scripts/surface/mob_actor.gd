class_name MobActor
extends CharacterBody3D
## ACTIVE-only adapter shared by every species. Logic state is in MobDomain.
var system: MobSimulation
var entity_id: String
var definition: Dictionary
var intent := "WANDER"
var _life := ""
var _facing := Vector3.FORWARD
var _attack_time := -1.0
var _attack_hit := false
var _query := PhysicsShapeQueryParameters3D.new()
var _hit := HitPayload.new()
var mesh: MeshInstance3D
var label: Label3D
var collision: CollisionShape3D

func _ready() -> void:
	definition = SurfaceCatalog.data().mobs[system.domain.states[entity_id].definition]
	collision_layer = 8
	collision_mask = 1|2|4|16
	floor_snap_length = .5
	var shape := CapsuleShape3D.new()
	shape.radius = float(definition.radius)
	shape.height = float(definition.height)
	collision = CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = shape.height*.5
	add_child(collision)
	mesh = MeshInstance3D.new()
	mesh.mesh = load("res://resources/surface/"+str(definition.visual)+".res")
	add_child(mesh)
	label = Label3D.new()
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 26
	label.pixel_size = .006
	label.position.y = float(definition.height)+.3
	add_child(label)
	var volume := BoxShape3D.new()
	volume.size = Vector3(1.2,1.5,1.6)
	_query.shape = volume
	_query.collision_mask = 2
	sync_life()

func sync_life() -> void:
	var state: Dictionary = system.domain.states[entity_id]
	if _life != state.life:
		_life = state.life
		if _life == "ALIVE":
			add_to_group("combat_targets")
		else:
			remove_from_group("combat_targets")
			add_to_group("interactables")
			collision_layer = 4
			mesh.rotation.z = PI*.5
			mesh.scale = Vector3.ONE*.7
			collision.scale = Vector3(1,.3,1)
			collision.position.y = .2
	label.text = str(definition.title)+(" • %d"%state.health if _life == "ALIVE" else " • Corpo")
	if _life == "ALIVE" and intent == "WARN_ATTACK":
		label.text += "\nAfaste-se!"

func _physics_process(delta: float) -> void:
	if not system.runtime.player.spawned or system.runtime.player.inventory.is_open or _life != "ALIVE":
		return
	var player := system.runtime.player
	var direction := player.global_position-global_position
	direction.y = 0
	var desired := Vector3.ZERO
	if intent == "FLEE":
		desired = -direction.normalized()
	elif intent == "ATTACK":
		desired = direction.normalized()
	elif intent == "WANDER":
		var angle := float(posmod(entity_id.hash()+int(system.runtime.ledger.clock/5),628))/100.0
		desired = Vector3(sin(angle),0,cos(angle))*.35
	if _attack_time >= 0:
		desired = Vector3.ZERO
		_attack_time += delta
		if not _attack_hit and _attack_time >= .4:
			_query.transform = Transform3D(Basis.looking_at(_facing),global_position+Vector3.UP*.7+_facing*.8)
			for body: Dictionary in get_world_3d().direct_space_state.intersect_shape(_query,4):
				if body.collider == player:
					_hit.raw_damage = float(definition.damage)
					_hit.impulse = _facing*1.8
					_hit.attack_id = "mob.melee"
					player.combat.receive_hit(_hit)
			_attack_hit = true
		if _attack_time >= 1.1:
			_attack_time = -1
	elif intent == "ATTACK" and direction.length() < 1.8:
		_attack_time = 0
		_attack_hit = false
		_facing = direction.normalized() if not direction.is_zero_approx() else Vector3.FORWARD
	if not desired.is_zero_approx():
		_facing = desired.normalized()
	velocity.x = move_toward(velocity.x,desired.x*float(definition.speed),12*delta)
	velocity.z = move_toward(velocity.z,desired.z*float(definition.speed),12*delta)
	velocity.y = -.2 if is_on_floor() else velocity.y-18*delta
	if not system.runtime.terrain.collision_data_ready(global_position+velocity*delta):
		velocity.x = 0
		velocity.z = 0
	move_and_slide()

func receive_hit(hit: HitPayload) -> float:
	system.domain.states[entity_id].position = [global_position.x,global_position.y,global_position.z]
	var amount := system.domain.hit(entity_id,hit)
	velocity += hit.impulse
	sync_life()
	return amount

func interact(_actor: PlayerActor) -> void:
	var state: Dictionary = system.domain.states[entity_id]
	if state.life == "CORPSE":
		system.runtime.container_opened.emit(state.corpse_inventory)

func harvest() -> void:
	system.harvest_corpse(entity_id)
