extends Node
## Disk recovery/forward-version gates use an isolated QA namespace only.

const DIRECTORY := "user://qa_p02_state"
const PROFILE := {"save_id": "0123456789abcdef0123456789abcdef", "world_seed": 424242,
	"world_generation_version": 1, "world_profile": "chapter1_iteration_480m_v1"}
var failures := 0

class FieldTerrain extends VoxelTerrainAdapter:
	func surface_hit(_x: float, _z: float) -> Dictionary:
		return {}

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("WORLD_STATE FAIL " + label)

func _clean() -> void:
	if not DirAccess.dir_exists_absolute(DIRECTORY):
		return
	for filename: String in DirAccess.get_files_at(DIRECTORY):
		DirAccess.remove_absolute(DIRECTORY.path_join(filename))

func _put(path: String, value: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(value)
	file.close()

func _verify_codec() -> void:
	var buffer := VoxelBuffer.new()
	buffer.create(1, 1, 1)
	for raw: int in [0, 1, 32767, 32768, 65535]:
		buffer.set_voxel(raw, 0, 0, 0, VoxelBuffer.CHANNEL_SDF)
		var signed_code := raw - 65536 if raw >= 32768 else raw
		_check(absf(DensityCodec.metres(signed_code) - buffer.get_voxel_f(0, 0, 0, VoxelBuffer.CHANNEL_SDF) * WorldCoordinates.VOXEL_SIZE) < 0.0001, "distance codec physical units")

func _run() -> void:
	_clean()
	_verify_codec()
	var store := WorldDeltaStore.new(DIRECTORY, PROFILE)
	_check(store.load_world() == OK, "new world")
	var changes := {
		Vector3i(127,24,0): {"density": 100, "materials": [0,15,0,0]},
		Vector3i(128,24,0): {"density": 166, "materials": [0,15,0,0]},
		Vector3i(-1,128,0): {"density": -66, "materials": [15,0,0,0]}}
	_check(store.commit(changes) == OK and store.metrics().edited_chunks == 3, "atomic cross-chunk/vertical records")
	var reloaded := WorldDeltaStore.new(DIRECTORY, PROFILE)
	_check(reloaded.load_world() == OK and reloaded.snapshot_box(Vector3i(-5,0,-5), Vector3i(150,150,10)) == changes, "fresh store exact reload")
	var stale := WorldDeltaStore.new(DIRECTORY, PROFILE)
	_check(stale.load_world() == OK, "second reader")
	var painted := {Vector3i(127,24,0): {"density": 100, "materials": [0,0,15,0]}}
	_check(store.commit(painted) == OK, "material revision")
	_check(stale.commit(changes) == ERR_ALREADY_IN_USE, "stale writer cannot lose a committed revision")
	var active := DIRECTORY.path_join("active.json")
	var good := FileAccess.get_file_as_string(active)
	_put(active + ".tmp", "{interrupted")
	reloaded = WorldDeltaStore.new(DIRECTORY, PROFILE)
	_check(reloaded.load_world() == OK and reloaded.revision == 2, "partial temporary ignored")
	_put(active, "{truncated")
	reloaded = WorldDeltaStore.new(DIRECTORY, PROFILE)
	_check(reloaded.load_world() == OK and reloaded.recovered and reloaded.revision == 1, "truncated index recovers whole previous revision")
	_check(reloaded.snapshot_box(Vector3i(-5,0,-5), Vector3i(150,150,10)) == changes, "no half border edit after recovery")
	var header: Dictionary = JSON.parse_string(good)
	header.schema_version = 99
	var future := JSON.stringify(header)
	_put(active, future)
	reloaded = WorldDeltaStore.new(DIRECTORY, PROFILE)
	_check(reloaded.load_world() == ERR_UNAVAILABLE and store.commit(changes) == ERR_UNAVAILABLE, "future index never replaced by backup/write")
	_check(FileAccess.get_file_as_string(active) == future, "future bytes preserved")
	_put(active, good)
	header = JSON.parse_string(good)
	var index: Dictionary = JSON.parse_string(header.payload)
	var record_path: String = DIRECTORY.path_join(index.records["0_0_0"])
	var record_good := FileAccess.get_file_as_string(record_path)
	var record: Dictionary = JSON.parse_string(record_good)
	record.payload += " " # Valid JSON still, but checksum differs.
	_put(record_path, JSON.stringify(record))
	reloaded = WorldDeltaStore.new(DIRECTORY, PROFILE)
	_check(reloaded.load_world() == OK and reloaded.recovered and reloaded.revision == 1, "chunk checksum recovers previous complete revision")
	record = JSON.parse_string(record_good)
	record.schema_version = 99
	_put(record_path, JSON.stringify(record))
	reloaded = WorldDeltaStore.new(DIRECTORY, PROFILE)
	_check(reloaded.load_world() == ERR_UNAVAILABLE, "future chunk blocks fallback")
	var wrong_identity := PROFILE.duplicate()
	wrong_identity.world_seed = 42
	_check(WorldDeltaStore.new(DIRECTORY, wrong_identity).load_world() != OK, "identity prevents cross-save terrain")
	var metadata := {"save_id": PROFILE.save_id}
	_check(WorldIdentity.establish(metadata) == OK, "P01 identity upgrade")
	var world_seed: int = metadata.world_seed
	_check(WorldIdentity.establish(metadata) == OK and metadata.world_seed == world_seed, "identity stable on reload")
	metadata.world_generation_version = 99
	_check(WorldIdentity.establish(metadata) == ERR_UNAVAILABLE, "future generation rejected")
	_check(WorldIdentity.establish({"save_id": "../outside"}) != OK, "save path identity validated")
	var grid := BuildGrid.new()
	var cell := Vector3i(-1,2,3)
	_check(grid.reserve(cell, "fixture_owner") == OK and grid.occupant(cell) == "fixture_owner", "1m occupancy")
	_check(grid.reserve(cell, "other") == ERR_ALREADY_IN_USE and grid.release(cell, "other") == ERR_UNAUTHORIZED, "ownership conflict")
	_check(grid.release(cell, "fixture_owner") == OK and grid.occupant(cell).is_empty(), "release")
	_check(grid.reserve(Vector3i(0,101,0), "fixture") != OK, "100m ceiling")
	_check(BuildGrid.shared_edge(cell, cell + Vector3i.RIGHT) == BuildGrid.shared_edge(cell + Vector3i.RIGHT, cell), "shared edge canonical")
	_check(BuildGrid.shared_edge(cell, cell + Vector3i.UP).is_empty(), "wall edge rejects floor mismatch")
	_check(WorldBoundary.attenuate(Vector3(100,0,0), Vector3(7,0,0)) == Vector3(7,0,0), "normal traversal unaffected")
	var outward := WorldBoundary.attenuate(Vector3(400,0,0), Vector3(7,0,0))
	_check(outward.x > 0 and outward.x < 7, "soft boundary attenuation")
	_check(WorldBoundary.attenuate(Vector3(440,0,0), Vector3(7,0,0)).is_zero_approx(), "outer treadmill")
	_check(WorldBoundary.attenuate(Vector3(400,0,0), Vector3(-7,0,7)) == Vector3(-7,0,7), "inward/tangent escape allowed")
	_check(WorldBoundary.outside(Vector3(500,0,0)) and WorldBoundary.outside(Vector3(0,-129,0)), "hard safety")
	var terrain := FieldTerrain.new()
	var water := WorldWater.new()
	water.terrain = terrain
	_check(water.sample(Vector3(0,20,0)).kind == "dry", "spawn above ocean")
	_check(water.sample(Vector3(300,-1,0)).kind == "ocean" and water.sample(Vector3(300,-1,0)).submerged, "ocean depth/query")
	_check(water.sample(Vector3(-72,7,48)).kind == "lake", "generated lake query")
	water.invalidate_terrain(AABB(Vector3.ZERO, Vector3.ONE))
	_check(water.dirty_notifications == 1, "WaterGrid dirty seam")
	terrain.free()
	_clean()
	print("WORLD_STATE ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	get_tree().quit(0 if failures == 0 else 1)
