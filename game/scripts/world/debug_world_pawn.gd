class_name DebugWorldPawn
extends CharacterBody3D
## P02 inspection body only. P03 owns the real motor, appearance and interaction.

var terrain: VoxelTerrainAdapter
var spawned := false
var overview := false
var distance_travelled := 0.0

var water: WorldWater
var boundary_recoveries := 0

func _ready() -> void:
	$Camera.look_at(global_position)

func _physics_process(delta: float) -> void:
	if terrain == null or water == null:
		return
	if WorldBoundary.outside(global_position):
		inspect_at(Vector3(0, 30, 0))
		boundary_recoveries += 1
		return
	var water_sample := water.sample(global_position)
	if not spawned:
		var hit := terrain.surface_hit(global_position.x, global_position.z)
		if water_sample.kind != "dry":
			global_position.y = water_sample.level + 0.9
			spawned = true
		elif not hit.is_empty() and terrain.is_editable(hit.position, 2):
			global_position.y = hit.position.y + 1.1
			spawned = true
		return
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var horizontal := WorldBoundary.attenuate(global_position, Vector3(movement.x, 0, movement.y) * 7.0)
	velocity.x = horizontal.x
	velocity.z = horizontal.z
	if water_sample.kind != "dry" and global_position.y <= water_sample.level + 1.2:
		velocity.y = 0
		global_position.y = lerpf(global_position.y, water_sample.level + 0.9, minf(1, delta * 8))
	else:
		velocity.y -= 18.0 * delta
	var next := global_position + Vector3(velocity.x, 0, velocity.z) * delta
	if water.sample(next).kind == "dry" and terrain.surface_hit(next.x, next.z).is_empty():
		velocity.x = 0
		velocity.z = 0
	var previous := global_position
	move_and_slide()
	distance_travelled += global_position.distance_to(previous)

func inspect_at(point: Vector3) -> void:
	global_position = point
	velocity = Vector3.ZERO
	spawned = false

func toggle_overview() -> void:
	overview = not overview
	var camera: Camera3D = $Camera
	camera.position = Vector3(0, 350, 210) if overview else Vector3(0, 24, 20)
	camera.size = 550 if overview else 36
	camera.look_at(global_position)
