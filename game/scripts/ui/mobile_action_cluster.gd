class_name MobileActionCluster
extends Control
## Geometry only. TouchScreenButton owns native multitouch/action dispatch.

var buttons: Dictionary[String, Button] = {}
var touch_controls: Dictionary[String, TouchScreenButton] = {}

func _ready() -> void:
	name = "Actions"
	custom_minimum_size = Vector2(248, 210)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for entry: Array in [["Attack", "⚔", "attack_primary"], ["Interact", "💬", "interact"], ["Dodge", "💨", "dodge"], ["Context", "✦", "context_action"]]:
		var button := Button.new()
		button.name = entry[0]
		button.text = entry[1]
		button.tooltip_text = entry[2]
		button.mouse_filter = Control.MOUSE_FILTER_IGNORE
		button.focus_mode = Control.FOCUS_NONE
		for state: String in ["normal", "hover", "pressed", "disabled", "focus"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color("162b39") if state == "disabled" else Color("294859")
			style.border_color = Color("425761") if state == "disabled" else ShellUI.GOLD
			style.set_border_width_all(2)
			style.set_corner_radius_all(512)
			button.add_theme_stylebox_override(state, style)
		add_child(button)
		buttons[entry[0]] = button
		var touch := TouchScreenButton.new()
		touch.name = "NativeTouch"
		touch.action = entry[2]
		touch.visibility_mode = TouchScreenButton.VISIBILITY_ALWAYS
		button.add_child(touch)
		touch_controls[entry[0]] = touch
		touch.pressed.connect(func() -> void: button.modulate = Color(1.3, 1.3, 1.3))
		touch.released.connect(func() -> void: button.modulate = Color.WHITE)
	set_context_available(false)
	resized.connect(_arrange)
	_arrange.call_deferred()

func set_context_available(available: bool) -> void:
	buttons["Context"].disabled = not available
	touch_controls["Context"].visible = available

func _arrange() -> void:
	var diameter := minf(size.x, size.y) * 0.44
	var centers := {"Attack": Vector2(0.79, 0.78), "Interact": Vector2(0.50, 0.18), "Dodge": Vector2(0.17, 0.48), "Context": Vector2(0.78, 0.36)}
	for key: String in buttons:
		var extent := diameter if key == "Attack" else diameter * 0.75
		var button: Button = buttons[key]
		button.size = Vector2.ONE * extent
		button.position = size * centers[key] - button.size * 0.5
		button.add_theme_font_size_override("font_size", int(extent * 0.42))
		var shape := CircleShape2D.new()
		shape.radius = extent * 0.5
		touch_controls[key].shape = shape
		touch_controls[key].position = button.size * 0.5
