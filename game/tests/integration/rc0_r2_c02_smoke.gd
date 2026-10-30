extends Node
var failures := 0
var identity := {"save_id":"22222222222222222222222222222222","world_seed":424242,"world_generation_version":2,"world_profile":WorldGenerationProfile.ID}
func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("RC0_R2_C02 "+label)
func location() -> String:
	return "user://qa_r2_c02/"+Crypto.new().generate_random_bytes(8).hex_encode()
func sample(value: int) -> Dictionary:
	return {Vector3i.ZERO:{"density":value,"materials":[0,0,15,0]}}
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	var root := location()
	var store := BufferedWorldDeltaStore.new(root,identity)
	check(store.load_world() == OK,"empty load")
	for value: int in range(1,101):
		check(store.stage(sample(value)) == OK,"memory edit")
	check(store.revision == 0 and not FileAccess.file_exists(root.path_join("active.json")),"100 edits zero synchronous I/O")
	check(store.io_report().dirty_samples == 1,"coalesced sparse edits")
	store.begin_flush()
	check(store.stage(sample(200)) == OK,"new edit while checkpoint in flight")
	check(store.flush() == OK,"worker flush")
	var reload := BufferedWorldDeltaStore.new(root,identity)
	check(reload.load_world() == OK and reload.snapshot_box(Vector3i.ZERO,Vector3i.ONE)[Vector3i.ZERO].density == 200,"newer edit survives worker completion")
	check(store.batches == 2 and store.io_report().dirty_samples == 0,"two bounded snapshots")
	_journal(false)
	_journal(true)
	var broken := BufferedWorldDeltaStore.new(location(),identity)
	DirAccess.make_dir_recursive_absolute(broken.directory)
	var partial := FileAccess.open(broken.directory.path_join("terrain_pending.json.tmp"),FileAccess.WRITE)
	partial.store_string("partial")
	partial.close()
	check(broken.load_world() == OK,"incomplete uncommitted WAL ignored")
	var foreign := identity.duplicate()
	foreign.world_generation_version = 1
	check(BufferedWorldDeltaStore.new(root,foreign).load_world() != OK,"generator identity preserved")
	var previous := 0.0
	for level: int in range(2,11):
		var budget := GameSettings.distance_budget(level)
		check(budget.viewer_metres > previous and budget.near_ring >= 1,"distance budget monotonic")
		previous = budget.viewer_metres
	var pawn := Node3D.new()
	add_child(pawn)
	var viewer := VoxelViewer.new()
	pawn.add_child(viewer)
	var anchor := TerrainResidencyAnchor.new()
	add_child(anchor)
	anchor.set_process(false)
	anchor.configure(pawn,viewer)
	for index: int in 100:
		pawn.position.x = 1.0 if index%2 else -1.0
		anchor._process(.016)
	check(anchor.moves == 0,"boundary jitter does not churn native viewer")
	pawn.position = Vector3(8,65,0)
	anchor._process(.016)
	check(anchor.moves == 1 and WorldCoordinates.world_to_chunk(viewer.global_position).y == 1,"vertical viewer residency")
	anchor.queue_free()
	pawn.queue_free()
	await _native()
	print("RC0_R2_C02 ","PASS" if failures == 0 else "FAIL"," failures=",failures)
	get_tree().quit(1 if failures else 0)
func _journal(committed: bool) -> void:
	var root := location()
	var writer := WorldDeltaStore.new(root,identity)
	DirAccess.make_dir_recursive_absolute(root)
	var changes := sample(333)
	check(writer._write(root.path_join("terrain_pending.json"),writer._envelope("journal",{"base_revision":0,"changes":[[0,0,0,333,0,0,15,0]]}),"journal") == OK,"WAL durable")
	if committed:
		check(writer.commit(changes) == OK,"checkpoint before crash")
	var reader := BufferedWorldDeltaStore.new(root,identity)
	check(reader.load_world() == OK and reader.recovered and reader.revision == 1,"WAL roll forward/exactly once")
	check(reader.snapshot_box(Vector3i.ZERO,Vector3i.ONE)[Vector3i.ZERO].density == 333 and not FileAccess.file_exists(root.path_join("terrain_pending.json")),"recovery retains data and removes WAL")
func _native() -> void:
	var field := WorldFieldV2.new(424242)
	var store := BufferedWorldDeltaStore.new(location(),identity)
	check(store.load_world() == OK,"native delta load")
	var terrain: VoxelTerrainAdapter = load("res://scenes/world/WorldTerrain.tscn").instantiate()
	terrain.field = field
	terrain.deltas = store
	add_child(terrain)
	terrain.native.view_distance = 384
	var viewer := VoxelViewer.new()
	viewer.position = Vector3(0,9,0)
	viewer.view_distance = 192
	add_child(viewer)
	var edits := TerrainEditService.new()
	edits.terrain = terrain
	edits.store = store
	# Queue before collision/data is available; duplicate intent must coalesce.
	check(edits.request(Vector3(0,8,0),1) == OK,"unready strike accepted as intent")
	check(edits.request(Vector3(0,8,0),1) == OK and edits.coalesced == 1,"duplicate intent coalesced")
	# Give initial world loading a longer explicit QA deadline; production uses800ms.
	for key: String in edits._queue:
		edits._queue[key].deadline = Time.get_ticks_msec()+25000
	var started := Time.get_ticks_msec()
	while edits.accepted == 0 and Time.get_ticks_msec()-started < 25000:
		edits.poll()
		await get_tree().process_frame
	check(edits.accepted == 1 and edits.pending_count() == 0,"queued intent executes once when local region ready")
	check(store.revision == 0 and store.io_report().dirty_samples > 0,"real native strike stages without disk write")
	check(store.flush() == OK,"native explicit save")
	var saved_density := terrain.density_at(Vector3(0,8,0))
	print("R2_C02_NATIVE ",JSON.stringify({"io":store.io_report(),"queue":edits.queue_report(),"terrain":terrain.statistics()}))
	terrain.queue_free()
	viewer.queue_free()
	await get_tree().process_frame
	var reloaded := BufferedWorldDeltaStore.new(store.directory,identity)
	check(reloaded.load_world() == OK,"native reload checkpoint")
	terrain = load("res://scenes/world/WorldTerrain.tscn").instantiate()
	terrain.field = field
	terrain.deltas = reloaded
	add_child(terrain)
	viewer = VoxelViewer.new()
	viewer.position = Vector3(0,9,0)
	viewer.view_distance = 128
	add_child(viewer)
	started = Time.get_ticks_msec()
	while not terrain.is_editable(Vector3(0,8,0),1) and Time.get_ticks_msec()-started < 25000:
		await get_tree().process_frame
	check(is_equal_approx(saved_density,terrain.density_at(Vector3(0,8,0))),"native unload/reload retains edited SDF")
	terrain.queue_free()
	viewer.queue_free()
	await get_tree().process_frame
