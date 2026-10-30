extends "res://tests/integration/surface_benchmark.gd"
## Matched R1 camera/seed/residency. Same production buffered terrain edit path.
var saver: TerrainSaveScheduler
var anchor: TerrainResidencyAnchor
var strike_result: Dictionary = {}
func _ready() -> void:
	super()
	var profile := {"save_id":"22222222222222222222222222222222","world_seed":424242,
		"world_generation_version":1,"world_profile":IslandField.PROFILE_ID}
	var store := BufferedWorldDeltaStore.new("user://qa_r2_bench/"+Crypto.new().generate_random_bytes(6).hex_encode(),profile)
	assert(store.load_world() == OK)
	surface.session.store = store
	surface.session.edits.store = store
	baseline.terrain.deltas = store
	baseline.terrain.native.stream.deltas = store
	saver = TerrainSaveScheduler.new()
	saver.store = store
	saver.edits = surface.session.edits
	add_child(saver)
	anchor = TerrainResidencyAnchor.new()
	add_child(anchor)
	anchor.configure(baseline.pawn,baseline.pawn.get_node("Viewer"))
func strikes() -> void:
	saver.set_process(false)
	var times: Array = []
	for index: int in 5:
		var center: Vector3 = baseline.pawn.global_position+Vector3(index*1.25,0,2)
		center.y = baseline.terrain.field.top_surface(center.x,center.z)
		var start := Time.get_ticks_msec()
		while not baseline.terrain.is_editable(center,1) and Time.get_ticks_msec()-start < 10000:
			await get_tree().process_frame
		start = Time.get_ticks_usec()
		var error: Error = surface.session.edits.apply(center,1)
		times.append({"ms":(Time.get_ticks_usec()-start)/1000.0,"error":error,"changed":surface.session.edits.last_result.get("changed_voxels",0)})
	var before := saver.store.io_report()
	var flush_start := Time.get_ticks_usec()
	var flush_error := saver.flush()
	strike_result = {"strikes":times,"before_flush":before,"flush_error":flush_error,"forced_flush_ms":(Time.get_ticks_usec()-flush_start)/1000.0,"after_flush":saver.store.io_report()}
	saver.set_process(true)
	print("R2_STRIKES ",JSON.stringify(strike_result))
func io_report() -> Dictionary:
	return {"io":saver.store.io_report(),"queue":saver.edits.queue_report(),"strikes":strike_result}

func quality(name_value: String, active: bool = true) -> void:
	surface.foliage.apply_quality(name_value,active)

func view(shoulder: bool) -> void:
	baseline.pawn.camera_rig.benchmark_legacy = false
	baseline.pawn.camera_rig.gameplay_mode = PlayerCameraRig.GameplayMode.SHOULDER if shoulder else PlayerCameraRig.GameplayMode.OVERVIEW
