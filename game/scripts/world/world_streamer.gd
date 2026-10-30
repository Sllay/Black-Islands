class_name WorldStreamer
extends Node
## Logical 64m residency, separate from native internal data/mesh/LOD blocks.
## Worker jobs prepare region descriptors; the main thread applies a bounded batch.

signal ring_changed
const HYSTERESIS := 8.0
const DEBOUNCE := 0.2
const APPLY_BUDGET := 4
var field: IslandField
var viewer: Node3D
var active: Dictionary = {}
var center := Vector3i.ZERO
var initialized := false
var plan_requests := 0
var applied := 0
var unloaded := 0
var last_transition_ms := 0
var _candidate := Vector3i.ZERO
var _stable_for := 0.0
var _task := -1
var _prepared: Array[Dictionary] = []
var _applying: Array[Dictionary] = []
var _next: Dictionary = {}
var _requested_center := Vector3i.ZERO
var _started := 0

func _process(delta: float) -> void:
	if viewer != null:
		update_target(viewer.global_position, delta)
	_poll()

func update_target(point: Vector3, delta: float) -> void:
	var wanted := WorldCoordinates.world_to_chunk(point)
	if initialized:
		var envelope := AABB(WorldCoordinates.chunk_origin(center) - Vector3.ONE * HYSTERESIS, Vector3.ONE * (64.0 + 2.0 * HYSTERESIS))
		if envelope.has_point(point):
			_stable_for = 0.0
			return
	if wanted != _candidate:
		_candidate = wanted
		_stable_for = 0.0
	_stable_for += delta
	if _task < 0 and _applying.is_empty() and (not initialized or _stable_for >= DEBOUNCE):
		_requested_center = wanted
		_started = Time.get_ticks_msec()
		_task = WorkerThreadPool.add_task(_prepare.bind(wanted), false, "Black Island region descriptors")
		plan_requests += 1

func _prepare(target: Vector3i) -> void:
	var result: Array[Dictionary] = []
	for z: int in range(target.z - 1, target.z + 2):
		for x: int in range(target.x - 1, target.x + 2):
			var layers: Dictionary = {}
			for offset: Vector2 in [Vector2(1, 1), Vector2(63, 1), Vector2(1, 63), Vector2(63, 63), Vector2(32, 32)]:
				var top := field.top_surface(x * 64.0 + offset.x, z * 64.0 + offset.y)
				if is_finite(top):
					layers[int(floor(top / 64.0))] = true
			if x == target.x and z == target.z:
				layers[target.y] = true # Player/water/vertical inspection need, including air.
			# Ocean-only regions have no dense terrain layer. Keep a lightweight region
			# descriptor so the horizontal near ring remains exactly nine addresses.
			if layers.is_empty():
				layers[0] = true
			for y: int in layers:
				var coord := Vector3i(x, y, z)
				result.append({"coord": coord, "seed": field.world_seed, "generation": field.generation_version,
					"forest": field.forest_weight(Vector3(x * 64 + 32, 0, z * 64 + 32)), "implicit_volume": true})
	_prepared = result

func _poll() -> void:
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		_applying = _prepared
		_prepared = []
		_next = {}
	for index: int in range(mini(APPLY_BUDGET, _applying.size())):
		var descriptor: Dictionary = _applying.pop_back()
		var coord: Vector3i = descriptor.coord
		_next[coord] = descriptor
		if not active.has(coord):
			active[coord] = descriptor
			applied += 1
	if _applying.is_empty() and not _next.is_empty():
		for coord: Vector3i in active.keys():
			if not _next.has(coord):
				active.erase(coord)
				unloaded += 1
		_next.clear()
		center = _requested_center
		initialized = true
		last_transition_ms = Time.get_ticks_msec() - _started
		ring_changed.emit()

func metrics() -> Dictionary:
	var horizontal: Dictionary = {}
	for coord: Vector3i in active:
		horizontal[Vector2i(coord.x, coord.z)] = true
	return {"center": center, "loaded_chunks": active.size(), "horizontal_regions": horizontal.size(),
		"pending_jobs": int(_task >= 0), "pending_apply": _applying.size(), "plans": plan_requests,
		"applied": applied, "unloaded": unloaded, "transition_ms": last_transition_ms}

func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
