class_name AtomicDocument
extends RefCounted
## Checksummed bounded document. Unknown future records never fall back silently.
var path: String
var schema: int
var identity: Dictionary
var loaded: Dictionary = {}
var revision := 0
var recovered := false

func _init(file_path: String, version: int, owner: Dictionary) -> void:
	path = file_path
	schema = version
	identity = owner

func read() -> Error:
	var result := inspect(path)
	if result.error == ERR_UNAVAILABLE:
		return ERR_UNAVAILABLE
	if result.error != OK:
		var backup := inspect(path+".bak")
		if backup.error == ERR_UNAVAILABLE:
			return ERR_UNAVAILABLE
		if backup.error == OK:
			result = backup
			recovered = true
		elif inspect(path+".tmp").error == OK:
			result = inspect(path+".tmp")
			recovered = true
		elif not FileAccess.file_exists(path) and not FileAccess.file_exists(path+".bak") and not FileAccess.file_exists(path+".tmp"):
			return OK
		else:
			return ERR_FILE_CORRUPT
	loaded = result.data
	revision = int(result.revision)
	return OK

func inspect(file_path: String) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		return {"error":ERR_DOES_NOT_EXIST}
	var row: Variant = JSON.parse_string(FileAccess.get_file_as_string(file_path))
	if not row is Dictionary:
		return {"error":ERR_FILE_CORRUPT}
	if float(row.get("schema",0)) > schema:
		return {"error":ERR_UNAVAILABLE}
	if row.get("schema") != schema or not row.get("identity") is Dictionary or row.identity.size() != identity.size() or not row.get("payload") is String or row.get("checksum") != row.payload.sha256_text():
		return {"error":ERR_FILE_CORRUPT}
	for key: String in identity:
		if row.identity.get(key) != identity[key]:
			return {"error":ERR_FILE_CORRUPT}
	var data: Variant = JSON.parse_string(row.payload)
	if not data is Dictionary or not (row.get("revision") is float or row.get("revision") is int) or row.revision < 1 or row.revision != int(row.revision):
		return {"error":ERR_FILE_CORRUPT}
	return {"error":OK,"data":data,"revision":row.revision}

func commit(data: Dictionary) -> Error:
	var primary := inspect(path)
	if primary.error == ERR_UNAVAILABLE:
		return ERR_UNAVAILABLE
	if primary.error == OK and int(primary.revision) != revision:
		return ERR_ALREADY_IN_USE
	var error := DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if error != OK:
		return error
	var payload := JSON.stringify(data,"",true)
	var row := {"schema":schema,"identity":identity,"revision":revision+1,"payload":payload,"checksum":payload.sha256_text()}
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(row))
	file.flush()
	error = file.get_error()
	file.close()
	if error != OK or inspect(path+".tmp").error != OK:
		return ERR_FILE_CORRUPT
	if primary.error == OK:
		error = DirAccess.copy_absolute(path,path+".bak")
		if error != OK:
			return error
	error = DirAccess.rename_absolute(path+".tmp",path)
	if error == OK:
		loaded = data.duplicate(true)
		revision += 1
	return error
