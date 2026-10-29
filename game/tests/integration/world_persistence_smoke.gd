extends Node
## Actual native terrain edit -> durable delta -> native unload/reload -> fresh terrain.

const DIRECTORY := "user://qa_p02_native"
const PROFILE := {"save_id": "abcdef0123456789abcdef0123456789", "world_seed": 424242,
	"world_generation_version": 1, "world_profile": "chapter1_iteration_480m_v1"}
var probe: Node3D
var terrain: VoxelTerrainAdapter
var store: WorldDeltaStore
var edits: TerrainEditService

class RejectingStore extends WorldDeltaStore:
	func commit(_changes: Dictionary) -> Error:
		return ERR_FILE_CANT_WRITE

func _ready() -> void:
	_run.call_deferred()

func _clean() -> void:
	if DirAccess.dir_exists_absolute(DIRECTORY):
		for filename: String in DirAccess.get_files_at(DIRECTORY):
			DirAccess.remove_absolute(DIRECTORY.path_join(filename))

func _open() -> bool:
	store = WorldDeltaStore.new(DIRECTORY, PROFILE)
	if store.load_world() != OK:
		return false
	probe = load("res://scenes/debug/WorldTerrainProbe.tscn").instantiate()
	terrain = probe.get_node("WorldTerrain")
	terrain.deltas = store
	probe.get_node("Viewer").position = Vector3(64, 16, 0)
	add_child(probe)
	edits = TerrainEditService.new()
	edits.terrain = terrain
	edits.store = store
	return await _wait_ready(Vector3(64, 18, 0))

func _wait_ready(point: Vector3) -> bool:
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if terrain.is_editable(point, 3) and not terrain.surface_hit(point.x, point.z).is_empty():
			return true
	return false

func _run() -> void:
	_clean()
	if not await _open():
		_fail("initial terrain")
		return
	var left: Vector3 = terrain.surface_hit(63.5, 0).position
	var right: Vector3 = terrain.surface_hit(64.5, 0).position
	var center: Vector3 = terrain.surface_hit(64, 0).position
	if edits.apply(center, 2) != OK or store.metrics().edited_chunks < 2:
		_fail("durable border removal")
		return
	var commit_ms: int = edits.last_result.commit_ms
	var deadline := Time.get_ticks_msec() + 10000
	var rebuilt := false
	while Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		var a := terrain.surface_hit(63.5, 0)
		var b := terrain.surface_hit(64.5, 0)
		rebuilt = not a.is_empty() and not b.is_empty() and a.position.y < left.y - 1 and b.position.y < right.y - 1
		if rebuilt:
			break
	if not rebuilt or not await _wait_ready(center):
		_fail("persistent edit collision")
		return
	var expected_sdf := terrain.density_at(center)
	var expected_y: float = terrain.surface_hit(64, 0).position.y
	var paint_center: Vector3 = terrain.surface_hit(66, 4).position
	if edits.apply(paint_center, 1.5, true, 2) != OK or terrain.material_at(paint_center) != 2:
		_fail("persistent material paint")
		return
	if not await _wait_ready(center):
		_fail("paint remesh")
		return
	# A failed disk commit must restore the native data, not accept unsaved truth.
	var rejected_center: Vector3 = terrain.surface_hit(60, 10).position
	var original := terrain.density_at(rejected_center)
	edits.store = RejectingStore.new(DIRECTORY, PROFILE)
	if edits.apply(rejected_center, 1) != ERR_FILE_CANT_WRITE or not edits.last_result.get("rolled_back", false):
		_fail("write failure propagation")
		return
	if not is_equal_approx(terrain.density_at(rejected_center), original) or not await _wait_ready(center):
		_fail("write failure rollback")
		return
	edits.store = store
	print("NATIVE_SAVE PASS ", store.metrics(), " border_commit_ms=", commit_ms)
	var block := terrain.native.voxel_to_data_block_position(Vector3(WorldCoordinates.world_to_voxel(center)), 0)
	var started := Time.get_ticks_msec()
	probe.get_node("Viewer").position = Vector3(-224, 16, 160)
	var unloaded := false
	deadline = started + 60000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if terrain.native.debug_get_data_block_info(Vector3(block), 0).loading_state == 0:
			unloaded = true
			break
	if not unloaded:
		_fail("native edited LOD0 data did not unload")
		return
	print("NATIVE_UNLOAD PASS block=", block, " elapsed_ms=", Time.get_ticks_msec() - started)
	started = Time.get_ticks_msec()
	probe.get_node("Viewer").position = Vector3(64, 16, 0)
	if not await _wait_ready(center):
		_fail("native reload")
		return
	if absf(terrain.density_at(center) - expected_sdf) > 0.0001 or absf(terrain.surface_hit(64,0).position.y - expected_y) > 0.03 or terrain.material_at(paint_center) != 2:
		print("RELOAD_TRACE sdf=", terrain.density_at(center), " expected=", expected_sdf, " y=", terrain.surface_hit(64,0).position.y, " expected_y=", expected_y, " material=", terrain.material_at(paint_center), " delta=", store.metrics())
		_fail("delta lost after native unload/reload")
		return
	print("NATIVE_RELOAD PASS elapsed_ms=", Time.get_ticks_msec() - started)
	if not await _verify_vertical():
		_fail("native vertical WorldChunk residency")
		return
	probe.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	if not await _open():
		_fail("fresh terrain from disk")
		return
	if absf(terrain.density_at(center) - expected_sdf) > 0.0001 or absf(terrain.surface_hit(64,0).position.y - expected_y) > 0.03 or terrain.material_at(paint_center) != 2:
		_fail("delta lost after fresh world")
		return
	print("WORLD_PERSISTENCE PASS seed=424242 native unload+fresh scene SDF+material+collision ", store.metrics())
	_clean()
	get_tree().quit()

func _verify_vertical() -> bool:
	var point := Vector3(64, -65, 0)
	var voxel := WorldCoordinates.world_to_voxel(point)
	var block := terrain.native.voxel_to_data_block_position(Vector3(voxel), 0)
	probe.get_node("Viewer").position = point
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
		if terrain.native.debug_get_data_block_info(Vector3(block), 0).loading_state == 2 and terrain.is_editable(point, 2):
			if terrain.density_at(point) >= 0:
				return false
			print("NATIVE_VERTICAL PASS logical=", WorldCoordinates.world_to_chunk(point), " native_lod0=", block)
			probe.get_node("Viewer").position = Vector3(64,16,0)
			return await _wait_ready(Vector3(64,18,0))
	return false

func _fail(message: String) -> void:
	push_error("WORLD_PERSISTENCE FAIL " + message)
	get_tree().quit(1)
