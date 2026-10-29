extends Node
## Scene navigation only. Profile authority lives in its own service.

const SAVE_SELECT := "res://scenes/ui/SaveSelect.tscn"
const MAIN := "res://scenes/main/Main.tscn"

func _ready() -> void:
	get_tree().auto_accept_quit = false
	get_tree().root.close_requested.connect(request_quit)

func _flush_players() -> Error:
	for coordinator: PlayerSaveCoordinator in get_tree().get_nodes_in_group("player_save_coordinators"):
		var error := coordinator.flush()
		if error != OK:
			return error
	return OK

func request_quit() -> void:
	if _flush_players() == OK:
		get_tree().quit()

func show_saves() -> void:
	if _flush_players() == OK:
		_navigate(SAVE_SELECT)

func enter_main() -> void:
	if Profiles.current_profile().is_empty():
		show_saves()
		return
	_navigate(MAIN)

func _navigate(scene_path: String) -> void:
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Scene navigation failed: %s (%s)" % [scene_path, error])
