extends Node
## Cross-scene lifetime is deliberate: UI and navigation never own profile truth.

signal selection_changed(slot_id: String)
var store := SlotStore.new()
var selected_slot_id := ""

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
	metadata["last_played_at"] = now
	var error := store.write_slot(metadata)
	if error == OK:
		selected_slot_id = slot_id
		selection_changed.emit(slot_id)
		print("PROFILE selected ", slot_id)
	return error

func current_profile() -> Dictionary:
	if selected_slot_id.is_empty():
		return {}
	return store.read_slot(selected_slot_id).metadata.duplicate(true)

func use_test_profiles() -> void:
	store = SlotStore.new("user://qa_profiles")
	selected_slot_id = ""

func use_production_profiles() -> void:
	store = SlotStore.new()
	selected_slot_id = ""
