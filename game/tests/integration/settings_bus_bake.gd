extends Node
## Explicit authoring bake invoked through Godot MCP, not part of validation.
func _ready() -> void:
	GameSettings.current = GameSettings.defaults()
	GameSettings.apply_safe()
	var error := ResourceSaver.save(AudioServer.generate_bus_layout(),"res://default_bus_layout.tres")
	print("AUDIO_BUS_BAKE ",error_string(error))
	get_tree().quit(error)
