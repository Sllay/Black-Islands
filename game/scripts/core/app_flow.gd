extends Node
## Scene navigation only. Profile authority lives in its own service.

const SAVE_SELECT := "res://scenes/ui/SaveSelect.tscn"
const MAIN := "res://scenes/main/Main.tscn"

func show_saves() -> void:
	_navigate(SAVE_SELECT)

func enter_main() -> void:
	_navigate(MAIN)

func _navigate(scene_path: String) -> void:
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Scene navigation failed: %s (%s)" % [scene_path, error])
