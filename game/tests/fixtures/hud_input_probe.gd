class_name HudInputProbe
extends RefCounted
## Synthetic native touch events are a desktop proxy, not physical-device proof.

static func _touch(index: int, position: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = position
	event.pressed = pressed
	(Engine.get_main_loop() as SceneTree).root.push_input(event, true)

static func _drag(index: int, position: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = position
	(Engine.get_main_loop() as SceneTree).root.push_input(event, true)

static func exercise(hud: Control, check: Callable) -> void:
	var tree := hud.get_tree()
	var joystick := hud.find_child("Movement", true, false) as VirtualJoystick
	check.call(joystick != null, "native VirtualJoystick replaces D-pad")
	if joystick == null:
		return
	var center := joystick.get_global_rect().get_center()
	for mode: int in [VirtualJoystick.JOYSTICK_FIXED, VirtualJoystick.JOYSTICK_DYNAMIC, VirtualJoystick.JOYSTICK_FOLLOWING]:
		joystick.joystick_mode = mode as VirtualJoystick.JoystickMode
		_touch(0, center, true)
		await tree.process_frame
		_drag(0, center + Vector2(150, 0))
		await tree.process_frame
		var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		check.call(direction.x > 0.5, "native mode %s emits movement" % mode)
		print("HUD_NATIVE_MODE ", mode, " vector=", direction)
		_touch(0, center + Vector2(150, 0), false)
		await tree.process_frame
	joystick.joystick_mode = VirtualJoystick.JOYSTICK_FIXED
	var cluster := hud.find_child("Actions", true, false) as MobileActionCluster
	for entry: Array in [["Attack", "attack_primary"], ["Dodge", "dodge"], ["Interact", "interact"]]:
		_touch(0, center, true)
		await tree.process_frame
		_drag(0, center + Vector2(70, 0))
		await tree.process_frame
		var target: Vector2 = cluster.buttons[entry[0]].get_global_rect().get_center()
		_touch(1, target, true)
		await tree.process_frame
		check.call(Input.get_vector("move_left", "move_right", "move_up", "move_down").x > 0.5 and Input.is_action_pressed(entry[1]), "simultaneous joystick + " + entry[0])
		_touch(1, target, false)
		await tree.process_frame
		check.call(Input.get_vector("move_left", "move_right", "move_up", "move_down").x > 0.5, "right release preserves left touch")
		_touch(0, center + Vector2(70, 0), false)
		await tree.process_frame
		check.call(not Input.is_action_pressed(entry[1]) and Input.get_vector("move_left", "move_right", "move_up", "move_down").is_zero_approx(), "native touch release")
		print("HUD_SIMULTANEOUS ", entry[0], " desktop synthetic events")
	var context_rect: Rect2 = cluster.buttons["Context"].get_rect()
	cluster.set_context_available(true)
	cluster.set_context_available(false)
	check.call(cluster.buttons["Context"].get_rect() == context_rect and cluster.buttons["Context"].disabled, "context geometry stable while disabled")
	for key: String in ["Interact", "Dodge", "Context"]:
		check.call(cluster.buttons[key].size.x < cluster.buttons["Attack"].size.x, "attack size hierarchy")
