extends Control

func _ready() -> void:
	print("FLOW Main")
	ShellUI.setup(self)
	var hud: Control = load("res://scenes/ui/ProductionHUD.tscn").instantiate()
	add_child(hud)
