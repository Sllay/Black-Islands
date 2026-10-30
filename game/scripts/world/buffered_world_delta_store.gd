class_name BufferedWorldDeltaStore
extends WorldDeltaStore
## Gameplay memory is authoritative. Immutable checkpoints/WAL run off-thread.
## Existing terrain schema1, identity and density codec remain unchanged.
const MAX_PENDING_SAMPLES := 32768
const MAX_PENDING_CHUNKS := 16
var _pending: Dictionary = {}
var _epochs: Dictionary = {}
var _epoch := 0
var _pending_count := 0
var _task := -1
var _completion: Dictionary = {}
var _snapshot: Dictionary = {}
var last_error: Error = OK
var batches := 0
var journal_commits := 0
var last_flush_ms := 0.0
var last_capture_ms := 0.0

func _init(root: String, profile: Dictionary) -> void:
	super(root,profile)

func load_world() -> Error:
	var error := super.load_world()
	if error != OK:
		return error
	return _recover_journal()

func has_capacity(estimated_samples: int = 0) -> bool:
	return _pending_count+estimated_samples <= MAX_PENDING_SAMPLES and _pending.size() < MAX_PENDING_CHUNKS

func stage(changes: Dictionary) -> Error:
	if changes.is_empty():
		return OK
	if not has_capacity(changes.size()):
		return ERR_BUSY
	for voxel: Vector3i in changes:
		var row: Dictionary = changes[voxel]
		if not _valid_row([voxel.x,voxel.y,voxel.z,row.density,row.materials[0],row.materials[1],row.materials[2],row.materials[3]]):
			return ERR_INVALID_DATA
	_mutex.lock()
	_epoch += 1
	for voxel: Vector3i in changes:
		var chunk := WorldCoordinates.voxel_to_chunk(voxel)
		if not _chunks.has(chunk):
			_chunks[chunk] = {}
		if not _pending.has(chunk):
			_pending[chunk] = {}
		if not _pending[chunk].has(voxel):
			_pending_count += 1
		var row: Dictionary = changes[voxel].duplicate(true)
		_chunks[chunk][voxel] = row
		_pending[chunk][voxel] = row
		_epochs[chunk] = _epoch
	_mutex.unlock()
	return OK

func commit(changes: Dictionary) -> Error:
	# Explicit compatibility checkpoint. Production strikes call stage instead.
	var error := stage(changes)
	return flush() if error == OK else error

func begin_flush() -> void:
	poll()
	if _task >= 0 or _pending.is_empty():
		return
	var started := Time.get_ticks_usec()
	var chunks: Dictionary = {}
	_mutex.lock()
	for chunk: Vector3i in _pending:
		chunks[chunk] = _chunks[chunk].duplicate(true)
	_snapshot = {"chunks":chunks,"patches":_pending.duplicate(true),"epochs":_epochs.duplicate(),"records":_records.duplicate(),"revision":revision}
	_mutex.unlock()
	last_capture_ms = (Time.get_ticks_usec()-started)/1000.0
	_completion = {}
	_task = WorkerThreadPool.add_task(_write_worker.bind(_snapshot),false,"Black Island sparse terrain checkpoint")

func poll() -> void:
	if _task < 0 or not WorkerThreadPool.is_task_completed(_task):
		return
	WorkerThreadPool.wait_for_task_completion(_task)
	_task = -1
	_accept_completion()

func _accept_completion() -> void:
	last_error = int(_completion.get("error",ERR_CANT_CREATE)) as Error
	last_flush_ms = float(_completion.get("ms",0))
	if last_error != OK:
		return # Memory/WAL retained; explicit save reports failure, never drops edits.
	_mutex.lock()
	_records = _completion.records
	revision = int(_completion.revision)
	for chunk: Vector3i in _snapshot.patches:
		if _epochs.get(chunk) == _snapshot.epochs[chunk]:
			_pending.erase(chunk)
			_epochs.erase(chunk)
		elif _pending.has(chunk):
			for voxel: Vector3i in _snapshot.patches[chunk]:
				if _pending[chunk].get(voxel) == _snapshot.patches[chunk][voxel]:
					_pending[chunk].erase(voxel)
			if _pending[chunk].is_empty():
				_pending.erase(chunk)
				_epochs.erase(chunk)
	_pending_count = 0
	for rows: Dictionary in _pending.values():
		_pending_count += rows.size()
	_mutex.unlock()
	batches += 1
	journal_commits += 1
	_snapshot.clear()

func flush() -> Error:
	poll()
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_accept_completion()
	if last_error != OK:
		return last_error
	if not _pending.is_empty():
		begin_flush()
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_accept_completion()
	return last_error

func _serializer() -> WorldDeltaStore:
	return WorldDeltaStore.new(directory,{"save_id":identity.save_id,"world_seed":identity.world_seed,
		"world_generation_version":identity.generation,"world_profile":identity.profile})

func _write_worker(snapshot: Dictionary) -> void:
	var started := Time.get_ticks_usec()
	var writer := _serializer()
	writer._chunks = snapshot.chunks
	writer._records = snapshot.records
	writer.revision = int(snapshot.revision)
	var changes: Dictionary = {}
	var rows: Array = []
	for patch: Dictionary in snapshot.patches.values():
		changes.merge(patch)
		for voxel: Vector3i in patch:
			var row: Dictionary = patch[voxel]
			rows.append([voxel.x,voxel.y,voxel.z,row.density,row.materials[0],row.materials[1],row.materials[2],row.materials[3]])
	var path := directory.path_join("terrain_pending.json")
	var error := DirAccess.make_dir_recursive_absolute(directory)
	var current := writer.read_checkpoint_head(directory.path_join("active.json"))
	if error == OK and current.error == ERR_UNAVAILABLE:
		error = ERR_UNAVAILABLE
	elif error == OK and current.error == OK and int(current.revision) != int(snapshot.revision):
		error = ERR_ALREADY_IN_USE
	if error == OK:
		error = writer._write(path+".tmp",writer._envelope("journal",{"base_revision":snapshot.revision,"changes":rows}),"journal")
	if error == OK:
		error = DirAccess.rename_absolute(path+".tmp",path)
	if error == OK:
		error = writer.commit(changes)
	if error == OK:
		error = DirAccess.remove_absolute(path)
	_completion = {"error":error,"records":writer._records,"revision":writer.revision,"ms":(Time.get_ticks_usec()-started)/1000.0}

func _recover_journal() -> Error:
	var path := directory.path_join("terrain_pending.json")
	if not FileAccess.file_exists(path):
		return OK # Partial .tmp has not reached the WAL durability point.
	var journal := _read_envelope(path,"journal")
	if journal.error != OK:
		return journal.error
	var data: Dictionary = journal.payload
	if not _integer(data.get("base_revision")) or not data.get("changes") is Array or data.changes.size() > MAX_PENDING_SAMPLES:
		return ERR_FILE_CORRUPT
	var changes: Dictionary = {}
	for row: Variant in data.changes:
		if not _valid_row(row):
			return ERR_FILE_CORRUPT
		changes[Vector3i(row[0],row[1],row[2])] = {"density":int(row[3]),"materials":[int(row[4]),int(row[5]),int(row[6]),int(row[7])]}
	var error: Error = OK
	if revision == int(data.base_revision):
		error = super.commit(changes)
	elif revision == int(data.base_revision)+1:
		for voxel: Vector3i in changes:
			if _chunks.get(WorldCoordinates.voxel_to_chunk(voxel),{}).get(voxel) != changes[voxel]:
				return ERR_ALREADY_IN_USE
	else:
		return ERR_ALREADY_IN_USE
	if error != OK:
		return error
	recovered = true
	return DirAccess.remove_absolute(path)

func io_report() -> Dictionary:
	return {"dirty_chunks":_pending.size(),"dirty_samples":_pending_count,"writing":_task >= 0,"batches":batches,
		"journal_commits":journal_commits,"last_flush_ms":last_flush_ms,"last_capture_ms":last_capture_ms,"error":last_error}

func metrics() -> Dictionary:
	var result := super.metrics()
	result.merge(io_report())
	return result
