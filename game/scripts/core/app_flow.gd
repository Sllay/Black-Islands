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

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		# A platform suspension cannot wait for distant data. Cancel only intents
		# that never executed, then durably checkpoint all accepted domain state.
		for coordinator: PlayerSaveCoordinator in get_tree().get_nodes_in_group("player_save_coordinators"):
			if coordinator.terrain_saver != null:
				coordinator.terrain_saver.edits.cancel_pending()
		var error := _flush_players()
		if error != OK:
			push_warning("Lifecycle save failed: %s"%error)

func show_saves() -> void:
	if Profiles.world_slot > 0:
		show_worlds()
	elif _flush_players() == OK:
		_navigate(SAVE_SELECT)

var edit_slot := 0
var edit_existing := false

func show_menu() -> void:
	if _flush_players() == OK:
		_navigate("res://scenes/ui/MainMenu.tscn")

func show_options() -> void:
	_navigate("res://scenes/ui/Options.tscn")

func show_worlds() -> void:
	if _flush_players() == OK:
		_navigate("res://scenes/ui/Worlds.tscn")

func show_players() -> void:
	if Profiles.world_slot <= 0:
		show_worlds()
	else:
		_navigate("res://scenes/ui/PlayerProfiles.tscn")

func edit_world(slot: int, existing: bool) -> void:
	edit_slot = slot
	edit_existing = existing
	_navigate("res://scenes/ui/WorldEditor.tscn")

func edit_player(slot: int, existing: bool) -> void:
	edit_slot = slot
	edit_existing = existing
	_navigate("res://scenes/ui/CharacterEditor.tscn")

func enter_main() -> void:
	if Profiles.current_profile().is_empty():
		show_saves()
		return
	_navigate(MAIN)

func _navigate(scene_path: String) -> void:
	var error := get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("Scene navigation failed: %s (%s)" % [scene_path, error])
