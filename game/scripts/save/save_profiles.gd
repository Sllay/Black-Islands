extends Node
## Cross-scene lifetime is deliberate: UI and navigation never own profile truth.

signal selection_changed(slot_id: String)
var store := SlotStore.new()
var selected_slot_id := ""

var library := FrontendLibrary.new()
var world_slot := 0
var player_slot := 0

func active_player() -> Dictionary:
	return library.read("player",player_slot)

func summaries() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot_id: String in SlotStore.SLOT_IDS:
		var summary := store.read_slot(slot_id)
		summary["slot_id"] = slot_id
		result.append(summary)
	return result

func select_slot(slot_id: String) -> Error:
	var summary := store.read_slot(slot_id)
	if summary.state == "unavailable":
		return ERR_FILE_CORRUPT
	var metadata: Dictionary = summary.metadata.duplicate(true)
	var now := Time.get_datetime_string_from_system(true) + "Z"
	if summary.state == "empty":
		metadata = {
			"schema_version": SlotStore.SCHEMA_VERSION, "slot_id": slot_id,
			"save_id": Crypto.new().generate_random_bytes(16).hex_encode(),
			"created_at": now, "display_name": "Jornada %s" % slot_id.trim_prefix("slot_"),
		}
	var identity_error := WorldIdentity.establish(metadata)
	if identity_error != OK:
		return identity_error
	metadata["last_played_at"] = now
	var error := store.write_slot(metadata)
	if error == OK:
		selected_slot_id = slot_id
		selection_changed.emit(slot_id)
		print("PROFILE selected ", slot_id)
	return error

func current_profile() -> Dictionary:
	if world_slot > 0:
		return library.read("world",world_slot)
	if selected_slot_id.is_empty():
		return {}
	return store.read_slot(selected_slot_id).metadata.duplicate(true)

func use_test_profiles() -> void:
	world_slot = 0
	player_slot = 0
	store = SlotStore.new("user://qa_profiles")
	selected_slot_id = ""

func reset_test_profiles() -> Error:
	if store.directory != "user://qa_profiles":
		return ERR_UNAUTHORIZED
	for slot_id: String in SlotStore.SLOT_IDS:
		for suffix: String in [".json", ".json.bak", ".json.tmp"]:
			var path := store.directory.path_join(slot_id + suffix)
			if FileAccess.file_exists(path):
				var error := DirAccess.remove_absolute(path)
				if error != OK:
					return error
	selected_slot_id = ""
	return OK

func use_production_profiles() -> void:
	world_slot = 0
	player_slot = 0
	store = SlotStore.new()
	selected_slot_id = ""
