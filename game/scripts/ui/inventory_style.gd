class_name InventoryStyle
extends RefCounted
static func panel() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("142d38")
	style.border_color = ShellUI.GOLD
	style.set_border_width_all(1)
	style.set_corner_radius_all(12)
	style.set_content_margin_all(16)
	return style
