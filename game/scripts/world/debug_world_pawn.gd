class_name DebugWorldPawn
extends CharacterBody3D
## P02 inspection body only. P03 owns the real motor, appearance and interaction.

var terrain: VoxelTerrainAdapter
var spawned := false
var overview := false
var distance_travelled := 0.0

func _ready() -> void:
	$Camera.look_at(global_position)

func _physics_process(delta: float) -> void:
	if terrain == null:
		return
	if not spawned:
		var hit := terrain.surface_hit(global_position.x, global_position.z)
		if not hit.is_empty() and terrain.is_editable(hit.position, 2):
			global_position.y = hit.position.y + 1.1
			spawned = true
		return
	var movement := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity.x = movement.x * 7.0
	velocity.z = movement.y * 7.0
	velocity.y -= 18.0 * delta
	# Do not step into an unready collider at a streaming frontier.
	var next := global_position + Vector3(velocity.x, 0, velocity.z) * delta
	if terrain.surface_hit(next.x, next.z).is_empty():
		velocity.x = 0.0
		velocity.z = 0.0
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
