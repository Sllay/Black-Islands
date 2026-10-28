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
	var stats := ShellUI.column(top, 6)
	for entry: Array in [["Health", "VIDA", 320, Color("cf786c")], ["Stamina", "VIGOR", 270, Color("a2c79b")], ["Mana", "MANA", 220, Color("84b9d6")]]:
		var resource := ShellUI.column(stats, 2)
		resource.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		resource.name = entry[0]
		resource.add_child(ShellUI.label_text(entry[1] + "     100 / 100", 16, entry[3]))
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(entry[2], 16)
		bar.value = 100
		bar.show_percentage = false
		var fill := StyleBoxFlat.new()
		fill.bg_color = entry[3]
		fill.corner_radius_top_left = 5
		fill.corner_radius_top_right = 5
		fill.corner_radius_bottom_left = 5
		fill.corner_radius_bottom_right = 5
		bar.add_theme_stylebox_override("fill", fill)
		resource.add_child(bar)
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
	var movement := GridContainer.new()
	movement.name = "Movement"
	movement.columns = 3
	bottom.add_child(movement)
	for entry: Array in [["", ""], ["↑", "move_up"], ["", ""], ["←", "move_left"], ["↓", "move_down"], ["→", "move_right"]]:
		if entry[1].is_empty():
			movement.add_child(Control.new())
		else:
			movement.add_child(_action(entry[0], entry[1]))
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
	var actions := GridContainer.new()
	actions.name = "Actions"
	actions.columns = 2
	bottom.add_child(actions)
	actions.add_child(_action("Interagir", "interact", Vector2(114, 56)))
	actions.add_child(_action("Esquivar", "dodge", Vector2(114, 56)))
	var context := ShellUI.button("Contexto", "Context", Vector2(114, 56))
	context.disabled = true
	actions.add_child(context)
	actions.add_child(_action("Atacar", "attack_primary", Vector2(114, 56)))

func _action(title: String, action: String, minimum := Vector2(56, 56)) -> Button:
	var button := ShellUI.button(title, action.to_pascal_case(), minimum)
	button.button_down.connect(func() -> void:
		Input.action_press(action)
		feedback.text = title)
	button.button_up.connect(func() -> void: Input.action_release(action))
	button.tree_exiting.connect(func() -> void: Input.action_release(action))
	return button
