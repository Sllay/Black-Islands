class_name HudResourceBar
extends HBoxContainer
## A display widget; callers supply presentation values, not authoritative stats.

func configure(node_name: String, icon: String, width: float, color: Color) -> void:
	name = node_name
	size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	add_theme_constant_override("separation", 10)
	var symbol := ShellUI.label_text(icon, 24, color)
	symbol.custom_minimum_size.x = 30
	symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(symbol)
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(width, 28)
	bar.value = 100
	bar.show_percentage = false
	for part: String in ["fill", "background"]:
		var style := StyleBoxFlat.new()
		style.bg_color = color if part == "fill" else ShellUI.INK.lightened(0.1)
		style.set_corner_radius_all(7)
		bar.add_theme_stylebox_override(part, style)
	add_child(bar)
	var percent := ShellUI.label_text("100%", 18, color.darkened(0.68))
	percent.name = "Percentage"
	percent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	percent.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	percent.mouse_filter = Control.MOUSE_FILTER_IGNORE
	percent.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bar.add_child(percent)

func set_fraction(current: float, maximum: float) -> void:
	var bar: ProgressBar = get_child(1)
	var value := clampf(current / maxf(1, maximum), 0, 1) * 100.0
	if is_equal_approx(bar.value, value):
		return
	bar.value = value
	var label: Label = bar.get_node("Percentage")
	var text_value := "%d%%" % roundi(value)
	if label.text != text_value:
		label.text = text_value
