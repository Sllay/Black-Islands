class_name ShellSafeArea
extends MarginContainer
## One conversion boundary from physical display pixels to logical UI units.

const GUTTER := 24.0
var simulated_insets := Vector4.ZERO

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	get_viewport().size_changed.connect(refresh)
	refresh.call_deferred()

func refresh() -> void:
	var insets := simulated_insets
	if OS.get_name() in ["Android", "iOS"]:
		var window := get_window()
		var physical := Rect2(Vector2(window.position), Vector2(window.size))
		var safe := Rect2(DisplayServer.get_display_safe_area()).intersection(physical)
		if safe.has_area() and physical.has_area():
			var scale_factor := get_viewport_rect().size / physical.size
			insets += Vector4(
				(safe.position.x - physical.position.x) * scale_factor.x,
				(safe.position.y - physical.position.y) * scale_factor.y,
				(physical.end.x - safe.end.x) * scale_factor.x,
				(physical.end.y - safe.end.y) * scale_factor.y)
	for index: int in range(4):
		var side: String = ["left", "top", "right", "bottom"][index]
		add_theme_constant_override("margin_" + side, int(GUTTER + maxf(insets[index], 0.0)))
