class_name InventoryQuantityModal
extends Control
signal confirmed(quantity: int)
signal cancelled
var item_title := ""
var source_title := ""
var target_title := ""
var source_quantity := 1
var maximum := 1
var amount := 1
var slider: HSlider
var input: LineEdit
var preview: Label
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0,0,0,.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",InventoryStyle.panel())
	panel.custom_minimum_size = Vector2(460,0)
	center.add_child(panel)
	var body := ShellUI.column(panel,12)
	body.add_child(ShellUI.label_text(item_title,24,ShellUI.GOLD))
	body.add_child(ShellUI.label_text("%s  →  %s"%[source_title,target_title],18))
	preview = ShellUI.label_text("",22)
	preview.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	body.add_child(preview)
	slider = HSlider.new()
	slider.name = "TransferSlider"
	slider.min_value = 1
	slider.max_value = maxi(1,maximum)
	slider.step = 1
	slider.custom_minimum_size = Vector2(400,48)
	slider.value_changed.connect(func(value: float) -> void: _sync(roundi(value)))
	body.add_child(slider)
	input = LineEdit.new()
	input.name = "TransferAmount"
	input.custom_minimum_size = Vector2(400,48)
	input.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	input.text_changed.connect(func(value: String) -> void:
		if not value.is_empty():
			_sync(value.to_int()))
	body.add_child(input)
	var buttons := HBoxContainer.new()
	body.add_child(buttons)
	var cancel := ShellUI.button("Cancelar","CancelTransfer",Vector2(195,52))
	cancel.pressed.connect(func() -> void: cancelled.emit())
	buttons.add_child(cancel)
	var confirm := ShellUI.button("Confirmar","ConfirmTransfer",Vector2(195,52))
	confirm.pressed.connect(func() -> void: confirmed.emit(amount))
	buttons.add_child(confirm)
	_sync(1)
func _sync(value: int) -> void:
	amount = clampi(value,1,maxi(1,maximum))
	slider.set_value_no_signal(amount)
	input.text = str(amount)
	input.caret_column = input.text.length()
	preview.text = "%d ficam     →     %d vão"%[source_quantity-amount,amount]
