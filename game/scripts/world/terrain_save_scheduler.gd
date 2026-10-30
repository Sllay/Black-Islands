class_name TerrainSaveScheduler
extends Node
## One coalesced worker per world; explicit lifecycle checkpoints may wait.
var store: BufferedWorldDeltaStore
var edits: TerrainEditService
var interval_seconds := 2.0
var _elapsed := 0.0

func _process(delta: float) -> void:
	edits.poll()
	store.poll()
	_elapsed += delta
	var info := store.io_report()
	if _elapsed >= interval_seconds or int(info.dirty_samples) >= 4096 or int(info.dirty_chunks) >= 8:
		_elapsed = 0
		store.begin_flush()

func flush() -> Error:
	edits.poll()
	# A still-pending intent is not reported as a saved action. Navigation waits
	# or receives a failure; expiry is separately surfaced to the player.
	if edits.pending_count() > 0:
		return ERR_BUSY
	return store.flush()

func _exit_tree() -> void:
	if store != null:
		store.flush()
