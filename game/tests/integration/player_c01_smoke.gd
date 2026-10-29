extends Node3D
## Physics, camera and target acquisition gate; native-world crossing is separate.

var failures := 0
var player: PlayerActor

class InteractableFixture extends StaticBody3D:
	var uses := 0
	func interact(_actor: Node3D) -> void:
		uses += 1

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("PLAYER_C01 FAIL " + label)

func _frames(count: int) -> void:
	for frame: int in range(count):
		await get_tree().physics_frame

func _target_fixture(point: Vector3, group: String, layer: int, height: float = 1.2) -> InteractableFixture:
	var body := InteractableFixture.new()
	body.position = point
	body.collision_layer = layer
	body.add_to_group(group)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(0.6, height, 0.6)
	collision.shape = shape
	collision.position.y = height * 0.5
	body.add_child(collision)
	add_child(body)
	return body

func _run() -> void:
	player = load("res://scenes/player/Player.tscn").instantiate()
	player.position = Vector3(0,3,0)
	add_child(player)
	await _frames(100)
	_check(player.is_on_floor() and absf(player.global_position.y) < 0.08, "gravity/floor/feet origin")
	_check(is_equal_approx(player.get_node("Collision").position.y, 0.8), "capsule offset from physical feet")
	player.camera_rig.heading_degrees = 90
	Input.action_press("move_right")
	await _frames(15)
	_check(player.velocity.z < -2 and absf(player.velocity.x) < 0.2, "camera-relative movement")
	Input.action_release("move_right")
	await _frames(20)
	_check(Vector2(player.velocity.x, player.velocity.z).length() < 0.1, "deceleration")
	player.camera_rig.heading_degrees = 0
	player.position = Vector3(0,0.05,-10)
	player.velocity = Vector3.ZERO
	Input.action_press("move_up")
	Input.action_press("run")
	await _frames(100)
	Input.action_release("run")
	Input.action_release("move_up")
	_check(player.global_position.z < -18 and player.global_position.y > 1.8, "smooth walkable slope traversal")
	_check(player.state.current_stamina < 95, "run consumes real stamina")
	await _frames(100)
	_check(player.state.current_stamina > 95, "stamina recovery")
	player.position = Vector3(9,0.05,0)
	player.velocity = Vector3.ZERO
	Input.action_press("move_up")
	await _frames(60)
	Input.action_release("move_up")
	_check(player.position.z < -3.5, "small step traversal")
	print("STEP_TRACE ", player.global_position, " velocity=", player.velocity, " floor=", player.is_on_floor())
	player.position = Vector3(0,0.05,0)
	player.velocity = Vector3.ZERO
	await _frames(5)
	var original := player.global_position
	player.camera_rig.reset_anchor()
	player.camera_rig.tick(1)
	_check(player.targeter.probe(Vector3.FORWARD).kind == TargetResult.Kind.TERRAIN, "terrain target")
	player.camera_rig.toggle_build()
	player.camera_rig.tick(1)
	_check(player.camera_rig.blend == 1 and player.targeter.probe(Vector3.FORWARD).kind == TargetResult.Kind.BUILD_GRID, "build camera + grid target")
	player.camera_rig.toggle_build()
	player.camera_rig.tick(1)
	_check(player.camera_rig.blend == 0 and player.global_position == original, "camera returns without moving player")
	var obstruction := _target_fixture(Vector3(0,0,4), "camera_obstacle", 1, 12)
	await _frames(3)
	var previous_count := player.camera_rig.obstruction_count
	player.camera_rig.tick(0.1)
	_check(player.camera_rig.obstruction_count > previous_count and player.camera_rig.camera.global_position.distance_to(player.global_position) < 12, "camera obstruction adjusts sightline")
	obstruction.queue_free()
	await _frames(3)
	var marker := _target_fixture(Vector3(0,0,-2), "interactables", 4)
	await _frames(3)
	_check(player.targeter.probe(Vector3.FORWARD).kind == TargetResult.Kind.INTERACTABLE and player.targeter.interact() and marker.uses == 1, "central interactable authority")
	var target := _target_fixture(Vector3(0,0,-3), "combat_targets", 8)
	await _frames(3)
	_check(player.targeter.probe(Vector3.FORWARD).kind == TargetResult.Kind.COMBAT_TARGET, "configurable combat target priority")
	player.targeter.priorities["INTERACTABLE"] = 50
	_check(player.targeter.probe(Vector3.FORWARD).kind == TargetResult.Kind.INTERACTABLE, "priority override is data-driven")
	player.targeter.priorities["INTERACTABLE"] = 30
	target.queue_free()
	marker.queue_free()
	var hud: Control = load("res://scenes/ui/ProductionHUD.tscn").instantiate()
	add_child(hud)
	hud.present_world()
	await _frames(4)
	await HudInputProbe.exercise(hud, _check)
	# Actions now drive real combat; let its explicit recovery finish before
	# measuring independent joystick locomotion (the InputMap test above overlaps).
	await _frames(40)
	var joystick := hud.find_child("Movement", true, false) as VirtualJoystick
	var center := joystick.get_global_rect().get_center()
	var before_touch := player.global_position
	HudInputProbe._touch(0, center, true)
	HudInputProbe._drag(0, center + Vector2(120,0))
	await _frames(30)
	_check(player.global_position.x > before_touch.x + 0.5, "native joystick drives real motor")
	HudInputProbe._touch(0, center + Vector2(120,0), false)
	print("PLAYER_C01 ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
