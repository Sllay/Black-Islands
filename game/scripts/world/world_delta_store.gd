class_name WorldDeltaStore
extends RefCounted
## Project-owned sparse voxel truth. Immutable chunk records + one atomic index
## commit keep a cross-WorldChunk operation all-or-nothing after a crash.
## No native mesh, collider or untouched generated volume is serialized.

const SCHEMA := 1
var directory: String
var identity: Dictionary
var revision := 0
var recovered := false
var _chunks: Dictionary = {}
var _records: Dictionary = {}
var _mutex := Mutex.new()

func _init(storage_directory: String, profile: Dictionary) -> void:
	directory = storage_directory
	identity = {"save_id": profile.save_id, "world_seed": profile.world_seed,
		"generation": profile.world_generation_version, "profile": profile.world_profile}

func load_world() -> Error:
	var path := directory.path_join("active.json")
	var result := _read_index(path)
	if result.error == ERR_UNAVAILABLE:
		return ERR_UNAVAILABLE # Never fall back over future data.
	if result.error != OK:
		var backup := _read_index(path + ".bak")
		if backup.error == ERR_UNAVAILABLE:
			return ERR_UNAVAILABLE
		if backup.error == OK:
			result = backup
			recovered = true
		elif not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".bak") and not FileAccess.file_exists(path + ".tmp"):
			return OK
		else:
			return ERR_FILE_CORRUPT
	_mutex.lock()
	_chunks = result.chunks
	_records = result.records
	revision = int(result.revision)
	_mutex.unlock()
	return OK

func commit(changes: Dictionary) -> Error:
	if changes.is_empty():
		return OK
	var error := DirAccess.make_dir_recursive_absolute(directory)
	if error != OK:
		return error
	_mutex.lock()
	var candidate := _chunks.duplicate()
	var records := _records.duplicate()
	_mutex.unlock()
	var dirty: Dictionary = {}
	for voxel: Vector3i in changes:
		var chunk := WorldCoordinates.voxel_to_chunk(voxel)
		if not dirty.has(chunk):
			candidate[chunk] = candidate.get(chunk, {}).duplicate(true)
			dirty[chunk] = true
		candidate[chunk][voxel] = changes[voxel].duplicate(true)
	for chunk: Vector3i in dirty:
		var rows: Array = []
		for voxel: Vector3i in candidate[chunk]:
			var sample: Dictionary = candidate[chunk][voxel]
			var row := [voxel.x, voxel.y, voxel.z, sample.density, sample.materials[0], sample.materials[1], sample.materials[2], sample.materials[3]]
			if not _valid_row(row):
				return ERR_INVALID_DATA
			rows.append(row)
		rows.sort_custom(func(a: Array, b: Array) -> bool:
			return a[2] < b[2] if a[2] != b[2] else (a[0] < b[0] if a[0] != b[0] else a[1] < b[1]))
		var payload := {"coord": [chunk.x, chunk.y, chunk.z], "voxels": rows}
		var envelope := _envelope("chunk", payload)
		var name := "chunk_%s_%s.json" % [_key(chunk), envelope.sha256]
		var record_path := directory.path_join(name)
		if _read_envelope(record_path, "chunk").error != OK:
			error = _write(record_path + ".tmp", envelope, "chunk")
			if error != OK:
				return error
			error = DirAccess.rename_absolute(record_path + ".tmp", record_path)
			if error != OK:
				return error
		records[_key(chunk)] = name
	var path := directory.path_join("active.json")
	# Preserve future or externally replaced data, even after this store was loaded.
	var primary := _read_index(path)
	if primary.error == ERR_UNAVAILABLE:
		return ERR_UNAVAILABLE
	if primary.error == OK and primary.revision != revision:
		return ERR_ALREADY_IN_USE
	var manifest := _envelope("index", {"revision": revision + 1, "records": records})
	error = _write(path + ".tmp", manifest, "index")
	if error != OK:
		return error
	if primary.error == OK:
		error = DirAccess.copy_absolute(path, path + ".bak")
		if error != OK:
			return error
	error = DirAccess.rename_absolute(path + ".tmp", path)
	if error != OK:
		return error
	_mutex.lock()
	_chunks = candidate
	_records = records
	revision += 1
	_mutex.unlock()
	return OK

func snapshot_box(origin: Vector3i, extent: Vector3i) -> Dictionary:
	var result: Dictionary = {}
	var first := WorldCoordinates.voxel_to_chunk(origin)
	var last := WorldCoordinates.voxel_to_chunk(origin + extent - Vector3i.ONE)
	var end := origin + extent
	_mutex.lock()
	for z: int in range(first.z, last.z + 1):
		for x: int in range(first.x, last.x + 1):
			for y: int in range(first.y, last.y + 1):
				var chunk: Dictionary = _chunks.get(Vector3i(x, y, z), {})
				for voxel: Vector3i in chunk:
					if voxel.x >= origin.x and voxel.y >= origin.y and voxel.z >= origin.z and voxel.x < end.x and voxel.y < end.y and voxel.z < end.z:
						result[voxel] = chunk[voxel].duplicate(true)
	_mutex.unlock()
	return result

func metrics() -> Dictionary:
	_mutex.lock()
	var samples := 0
	for chunk: Dictionary in _chunks.values():
		samples += chunk.size()
	var result := {"edited_chunks": _chunks.size(), "changed_voxels": samples, "revision": revision, "recovered": recovered}
	_mutex.unlock()
	return result

func _read_index(path: String) -> Dictionary:
	var index := _read_envelope(path, "index")
	if index.error != OK:
		return index
	var data: Dictionary = index.payload
	if not _integer(data.get("revision")) or not data.get("records") is Dictionary:
		return {"error": ERR_FILE_CORRUPT}
	var chunks: Dictionary = {}
	for key: Variant in data.records:
		var name: Variant = data.records[key]
		if not key is String or not name is String or not name.begins_with("chunk_" + key + "_") or name.get_file() != name or not name.ends_with(".json"):
			return {"error": ERR_FILE_CORRUPT}
		var record := _read_envelope(directory.path_join(name), "chunk")
		if record.error != OK:
			return record
		var payload: Dictionary = record.payload
		var coords: Variant = payload.get("coord")
		if not coords is Array or coords.size() != 3:
			return {"error": ERR_FILE_CORRUPT}
		for value: Variant in coords:
			if not _integer(value):
				return {"error": ERR_FILE_CORRUPT}
		var chunk := Vector3i(int(coords[0]), int(coords[1]), int(coords[2]))
		if _key(chunk) != key or not payload.get("voxels") is Array:
			return {"error": ERR_FILE_CORRUPT}
		var voxels: Dictionary = {}
		for row: Variant in payload.voxels:
			if not _valid_row(row):
				return {"error": ERR_FILE_CORRUPT}
			var voxel := Vector3i(int(row[0]), int(row[1]), int(row[2]))
			if WorldCoordinates.voxel_to_chunk(voxel) != chunk or voxels.has(voxel):
				return {"error": ERR_FILE_CORRUPT}
			voxels[voxel] = {"density": int(row[3]), "materials": [int(row[4]), int(row[5]), int(row[6]), int(row[7])]}
		chunks[chunk] = voxels
	return {"error": OK, "revision": data.revision, "records": data.records, "chunks": chunks}

func _envelope(kind: String, data: Dictionary) -> Dictionary:
	var payload := JSON.stringify(data)
	return {"schema_version": SCHEMA, "density_codec": DensityCodec.ID, "kind": kind, "identity": identity, "payload": payload, "sha256": payload.sha256_text()}

func _read_envelope(path: String, kind: String) -> Dictionary:
	if not FileAccess.file_exists(path):
		return {"error": ERR_DOES_NOT_EXIST}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null or file.get_length() > 32 * 1024 * 1024:
		return {"error": ERR_FILE_CORRUPT}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {"error": ERR_FILE_CORRUPT}
	var header: Dictionary = parser.data
	if _integer(header.get("schema_version")) and header.schema_version > SCHEMA:
		return {"error": ERR_UNAVAILABLE}
	if header.get("schema_version") == SCHEMA and header.get("density_codec") != DensityCodec.ID:
		return {"error": ERR_UNAVAILABLE}
	if header.get("schema_version") != SCHEMA or not _matches_identity(header.get("identity")) or header.get("kind") != kind or not header.get("payload") is String:
		return {"error": ERR_FILE_CORRUPT}
	if header.payload.sha256_text() != header.get("sha256"):
		return {"error": ERR_FILE_CORRUPT}
	if parser.parse(header.payload) != OK or not parser.data is Dictionary:
		return {"error": ERR_FILE_CORRUPT}
	return {"error": OK, "payload": parser.data}

func _matches_identity(value: Variant) -> bool:
	if not value is Dictionary:
		return false
	for key: String in identity:
		# JSON numbers are floats; Dictionary equality is type-strict in Godot.
		# Compare scalar identity fields so int/float round trips remain valid.
		if value.get(key) != identity[key]:
			return false
	return true

func _write(path: String, data: Dictionary, kind: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(data))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	return _read_envelope(path, kind).error

func _valid_row(row: Variant) -> bool:
	if not row is Array or row.size() != 8:
		return false
	for index: int in range(8):
		if not _integer(row[index]):
			return false
	for index: int in range(4, 8):
		if row[index] < 0 or row[index] > 15:
			return false
	return row[3] >= -32768 and row[3] <= 32767 and row[4] + row[5] + row[6] + row[7] > 0

func _integer(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value == int(value) and absf(value) < 33554432

func _key(coord: Vector3i) -> String:
	return "%d_%d_%d" % [coord.x, coord.y, coord.z]
