extends Control
## Presentation and semantic input only; no inventory, stats or combat authority.

var feedback: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var safe := ShellSafeArea.new()
	safe.name = "SafeArea"
	add_child(safe)
	var layout := ShellUI.column(safe, 16)
	var top := HBoxContainer.new()
	layout.add_child(top)
	var stats := ShellUI.column(top, 8)
	for entry: Array in [["Health", "❤️", 320, Color("cf786c")], ["Stamina", "⚡", 270, Color("a2c79b")], ["Mana", "🔮", 220, Color("84b9d6")]]:
		var resource := HudResourceBar.new()
		resource.configure(entry[0], entry[1], entry[2], entry[3])
		stats.add_child(resource)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var journey := ShellUI.column(top, 8)
	journey.add_child(ShellUI.label_text(Profiles.current_profile().get("display_name", "Black Island"), 20, ShellUI.GOLD))
	var return_button := ShellUI.button("Jornadas", "ReturnToSaves", Vector2(160, 56))
	return_button.pressed.connect(Flow.show_saves)
	journey.add_child(return_button)
	var middle := CenterContainer.new()
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(middle)
	var caption := ShellUI.column(middle, 12)
	caption.add_child(ShellUI.label_text("B L A C K   I S L A N D", 32, ShellUI.MUTED))
	feedback = ShellUI.label_text("Sua jornada começa aqui.", 18, ShellUI.MUTED)
	feedback.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_child(feedback)
	var bottom := HBoxContainer.new()
	bottom.add_theme_constant_override("separation", 20)
	bottom.alignment = BoxContainer.ALIGNMENT_CENTER
	layout.add_child(bottom)
	var movement := VirtualJoystick.new()
	movement.name = "Movement"
	movement.custom_minimum_size = Vector2(184, 184)
	movement.size_flags_vertical = Control.SIZE_SHRINK_END
	movement.joystick_size = 148
	movement.tip_size = 60
	movement.deadzone_ratio = 0.18
	movement.joystick_mode = VirtualJoystick.JOYSTICK_FIXED
	movement.visibility_mode = VirtualJoystick.VISIBILITY_ALWAYS
	movement.action_left = "move_left"
	movement.action_right = "move_right"
	movement.action_up = "move_up"
	movement.action_down = "move_down"
	bottom.add_child(movement)
	var hotbar := HBoxContainer.new()
	hotbar.name = "Hotbar"
	hotbar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hotbar.size_flags_vertical = Control.SIZE_SHRINK_END
	hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	hotbar.add_theme_constant_override("separation", 6)
	bottom.add_child(hotbar)
	var group := ButtonGroup.new()
	for index: int in range(8):
		var slot := ShellUI.button(str(index + 1), "Hotbar%d" % (index + 1), Vector2(54, 64))
		slot.toggle_mode = true
		slot.button_group = group
		slot.button_pressed = index == 0
		hotbar.add_child(slot)
	hotbar.add_child(_action("Bolsa", "inventory", Vector2(86, 64)))
	bottom.add_child(MobileActionCluster.new())

func _action(title: String, action: String, minimum := Vector2(56, 56)) -> Button:
	var button := ShellUI.button(title, action.to_pascal_case(), minimum)
	button.button_down.connect(func() -> void:
		Input.action_press(action)
		feedback.text = title)
	button.button_up.connect(func() -> void: Input.action_release(action))
	button.tree_exiting.connect(func() -> void: Input.action_release(action))
	return button
