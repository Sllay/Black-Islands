class_name PlayerSaveStore
extends RefCounted
## Small player record independent of immutable P02 terrain chunks/index.
const SCHEMA := 1
var directory: String
var identity: Dictionary
var loaded: Dictionary = {}
var revision := 0
var recovered := false
var _created_at: String

func _init(storage_directory: String, profile: Dictionary) -> void:
	directory = storage_directory
	identity = {"save_id":profile.save_id, "world_seed":profile.world_seed,
		"world_generation_version":profile.world_generation_version, "world_profile":profile.world_profile}
	_created_at = profile.created_at

func load_player() -> Error:
	var path := directory.path_join("player.json")
	var result := _read(path)
	if result.error == ERR_UNAVAILABLE:
		return ERR_UNAVAILABLE
	if result.error != OK:
		var backup := _read(path+".bak")
		if backup.error == ERR_UNAVAILABLE:
			return ERR_UNAVAILABLE
		if backup.error == OK:
			result = backup
			recovered = true
		elif not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak") and not FileAccess.file_exists(path+".tmp"):
			return OK # Existing P01/P02 save: initialize player lazily, keep world intact.
		else:
			return ERR_FILE_CORRUPT
	loaded = result.payload
	revision = int(result.revision)
	_created_at = result.created_at
	return OK

func commit(snapshot: Dictionary) -> Error:
	var candidate := loaded.duplicate(true)
	candidate.merge(snapshot,true) # Preserve unknown optional top-level fields.
	var validation := validate_snapshot(candidate)
	if validation != OK:
		return validation
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return error
	var path := directory.path_join("player.json")
	var primary := _read(path)
	if primary.error == ERR_UNAVAILABLE:
		return ERR_UNAVAILABLE
	if primary.error == OK and int(primary.revision) != revision:
		return ERR_ALREADY_IN_USE
	var payload := JSON.stringify(candidate)
	var envelope := {"save_schema_version":SCHEMA, "identity":identity, "revision":revision+1,
		"content_versions":{"inventory":ItemCatalog.VERSION,"combat":CombatCatalog.VERSION,"lpc":LPCCatalog.data().catalog_version},
		"created_at":_created_at, "last_saved_at":Time.get_datetime_string_from_system(true)+"Z",
		"payload":payload, "sha256":payload.sha256_text()}
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(envelope))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK:
		return error
	if _read(path+".tmp").error != OK:
		return ERR_FILE_CORRUPT
	if primary.error == OK:
		error = DirAccess.copy_absolute(path,path+".bak")
		if error != OK:
			return error
	error = DirAccess.rename_absolute(path+".tmp",path)
	if error == OK:
		revision += 1
		loaded = candidate
	return error

func _read(path: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error":ERR_DOES_NOT_EXIST}
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK or not parser.data is Dictionary:
		return {"error":ERR_FILE_CORRUPT}
	var header: Dictionary = parser.data
	var schema: Variant = header.get("save_schema_version")
	if (schema is int or schema is float) and schema > SCHEMA:
		return {"error":ERR_UNAVAILABLE}
	if schema != SCHEMA or not header.get("identity") is Dictionary or not header.get("payload") is String:
		return {"error":ERR_FILE_CORRUPT}
	for key: String in identity:
		if header.identity.get(key) != identity[key]:
			return {"error":ERR_FILE_CORRUPT}
	var versions: Variant = header.get("content_versions")
	if not versions is Dictionary or versions.get("inventory") != ItemCatalog.VERSION or versions.get("combat") != CombatCatalog.VERSION or versions.get("lpc") != LPCCatalog.data().catalog_version:
		return {"error":ERR_UNAVAILABLE}
	var saved_revision: Variant = header.get("revision")
	if not (saved_revision is float or saved_revision is int) or saved_revision < 1 or saved_revision != int(saved_revision) or not header.get("created_at") is String or not header.get("last_saved_at") is String:
		return {"error":ERR_FILE_CORRUPT}
	if header.payload.sha256_text() != header.get("sha256") or parser.parse(header.payload) != OK or not parser.data is Dictionary:
		return {"error":ERR_FILE_CORRUPT}
	var validation := validate_snapshot(parser.data)
	return {"error":validation,"payload":parser.data,"revision":saved_revision,"created_at":header.created_at}

static func validate_snapshot(data: Dictionary) -> Error:
	if data.get("schema_version") != 1:
		return ERR_UNAVAILABLE
	if not data.get("spawn") is Dictionary or data.spawn.get("context") != "surface" or not _vector(data.spawn.get("feet")) or not _vector(data.spawn.get("facing")):
		return ERR_INVALID_DATA
	var feet: Array = data.spawn.feet
	if WorldBoundary.outside(Vector3(feet[0],feet[1],feet[2])):
		return ERR_INVALID_DATA
	if not data.get("appearance") is Dictionary or LPCCatalog.normalize(data.appearance).is_empty():
		return ERR_UNAVAILABLE
	if not data.get("inventory") is Dictionary or InventoryState.new().restore(data.inventory) != OK:
		return ERR_INVALID_DATA
	if not data.get("stats") is Dictionary:
		return ERR_INVALID_DATA
	for key: String in ["health","stamina"]:
		var maximum: Variant = data.stats.get("max_"+key,100.0)
		var value: Variant = data.stats.get(key)
		if not (maximum is float or maximum is int) or not is_finite(float(maximum)) or maximum <= 0 or maximum > 100000:
			return ERR_INVALID_DATA
		if not (value is float or value is int) or not is_finite(float(value)) or value < 0 or value > maximum:
			return ERR_INVALID_DATA
	var defense: Variant = data.stats.get("defense")
	if not (defense is float or defense is int) or not is_finite(float(defense)) or defense < 0 or defense > 10000:
		return ERR_INVALID_DATA
	return OK

static func _vector(value: Variant) -> bool:
	if not value is Array or value.size() != 3:
		return false
	for scalar: Variant in value:
		if not (scalar is float or scalar is int) or not is_finite(float(scalar)):
			return false
	return true
