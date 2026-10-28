class_name SlotStore
extends RefCounted
## Versioned profile metadata only. World payloads belong to later phases.

const SCHEMA_VERSION := 1
const SLOT_IDS: Array[String] = ["slot_01", "slot_02", "slot_03", "slot_04"]
var directory: String

func _init(storage_directory: String = "user://profiles") -> void:
	directory = storage_directory

func read_slot(slot_id: String) -> Dictionary:
	if slot_id not in SLOT_IDS:
		return {"state": "unavailable", "metadata": {}}
	var path := _path(slot_id)
	var primary := _read(path, slot_id)
	# An older backup must never silently replace a future schema.
	if primary.get("future", false):
		return {"state": "unavailable", "metadata": {}}
	if primary.get("valid", false):
		return {"state": "ready", "metadata": primary.metadata}
	var backup := _read(path + ".bak", slot_id)
	if backup.get("valid", false):
		return {"state": "ready", "metadata": backup.metadata, "recovered": true}
	if not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak") and not FileAccess.file_exists(path + ".tmp"):
		return {"state": "empty", "metadata": {}}
	return {"state": "unavailable", "metadata": {}}

func write_slot(metadata: Dictionary) -> Error:
	var slot_id: String = metadata.get("slot_id", "")
	if not _valid(metadata, slot_id):
		return ERR_INVALID_DATA
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return error
	var path := _path(slot_id)
	var file := FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(metadata, "\t"))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK or not _read(path + ".tmp", slot_id).get("valid", false):
		return ERR_FILE_CORRUPT
	if _read(path, slot_id).get("valid", false):
		error = DirAccess.copy_absolute(path, path + ".bak")
		if error != OK:
			return error
	# Same-directory rename; failure preserves the primary/known-good backup.
	return DirAccess.rename_absolute(path + ".tmp", path)

func _path(slot_id: String) -> String:
	return directory.path_join(slot_id + ".json")

func _read(path: String, slot_id: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parser := JSON.new()
	var error := parser.parse(file.get_as_text())
	file.close()
	if error != OK or not parser.data is Dictionary:
		return {}
	var data: Dictionary = parser.data
	if data.get("schema_version", 0) is float or data.get("schema_version", 0) is int:
		if data.get("schema_version", 0) > SCHEMA_VERSION:
			return {"future": true}
	return {"valid": _valid(data, slot_id), "metadata": data}

func _valid(data: Dictionary, slot_id: String) -> bool:
	var schema: Variant = data.get("schema_version")
	if not (schema is int or schema is float):
		return false
	if slot_id not in SLOT_IDS or data.get("slot_id") != slot_id or schema != SCHEMA_VERSION:
		return false
	for key: String in ["save_id", "created_at", "last_played_at", "display_name"]:
		if not data.get(key) is String or data[key].is_empty() or data[key].length() > 128:
			return false
	return true
