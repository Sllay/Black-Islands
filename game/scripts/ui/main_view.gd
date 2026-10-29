extends Control

func _ready() -> void:
	print("FLOW Main")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = load("res://resources/ui/ShellTheme.tres")
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hud: Control = load("res://scenes/ui/ProductionHUD.tscn").instantiate()
	add_child(hud)
	hud.present_world()
