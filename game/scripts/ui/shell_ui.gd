class_name ShellUI
extends RefCounted
## Shared presentation primitives, not domain state.

const INK := Color("101f2b")
const PAPER := Color("edf1e7")
const MUTED := Color("9cb1b9")
const GOLD := Color("d9ba78")

static func setup(root: Control) -> void:
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.theme = load("res://resources/ui/ShellTheme.tres")
	var background := ColorRect.new()
	background.name = "Background"
	background.color = INK
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(background)

static func label_text(text: String, font_size: int = 22, color: Color = PAPER) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

static func column(parent: Node, spacing: int = 16) -> VBoxContainer:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", spacing)
	parent.add_child(box)
	return box

static func button(text: String, node_name: String, minimum := Vector2(64, 56)) -> Button:
	var control := Button.new()
	control.name = node_name
	control.text = text
	control.custom_minimum_size = minimum
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return control
