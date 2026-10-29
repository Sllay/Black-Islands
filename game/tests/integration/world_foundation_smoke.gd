extends Node
## Deterministic data and real asynchronous logical residency; native edits have their own gate.

var failures := 0

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("WORLD_FOUNDATION FAIL " + label)

func _settle(streamer: WorldStreamer, point: Vector3) -> void:
	streamer.update_target(point, 0.25)
	for index: int in range(120):
		await get_tree().process_frame
		var report := streamer.metrics()
		if report.pending_jobs == 0 and report.pending_apply == 0:
			return
	_check(false, "residency job timeout")

func _run() -> void:
	var a := IslandField.new(424242)
	var b := IslandField.new(424242)
	var c := IslandField.new(7654321)
	var changed := 0
	var samples := 0
	var materials: Dictionary = {}
	for z: int in range(-180, 181, 18):
		for x: int in range(-180, 181, 18):
			var point := Vector3(x, a.top_surface(x, z), z)
			if not point.is_finite():
				continue
			samples += 1
			_check(a.density(point) == b.density(point) and a.material_at(point) == b.material_at(point), "same seed samples")
			if absf(a.surface_height(x, z) - c.surface_height(x, z)) > 0.1:
				changed += 1
			materials[a.material_at(point)] = true
			materials[a.material_at(point - Vector3(0, 10, 0))] = true
			materials[a.material_at(point - Vector3(0, 14, 0))] = true
	_check(changed > samples * 0.5, "different seed changes island")
	_check(materials.size() == 4, "sand grass soil stone")
	_check(is_equal_approx(a.top_surface(0, 0), 12) and is_equal_approx(a.top_surface(10, 0), 12), "buildable spawn")
	_check(a.forest_weight(Vector3(55, 0, 0)) > a.forest_weight(Vector3(210, 0, 0)), "forest region mask")
	_check(a.top_surface(-72, 48) < a.lake_body().level, "generated sleeping lake hook")
	# Native callback samples shared by LOD0/LOD1 must agree, including shortcut blocks.
	var generator := VoxelIslandGenerator.new()
	generator.field = a
	for origin: Vector3i in [Vector3i(0, 16, 0), Vector3i(384, 0, 0), Vector3i(0, -80, 0), Vector3i(0, 80, 0)]:
		var fine := VoxelBuffer.new()
		var coarse := VoxelBuffer.new()
		fine.create(16, 16, 16)
		coarse.create(8, 8, 8)
		generator._generate_block(fine, origin, 0)
		generator._generate_block(coarse, origin, 1)
		for z: int in range(8):
			for x: int in range(8):
				for y: int in range(8):
					_check(fine.get_voxel_f(x * 2, y * 2, z * 2, VoxelBuffer.CHANNEL_SDF) == coarse.get_voxel_f(x, y, z, VoxelBuffer.CHANNEL_SDF), "LOD shared SDF")
	var streamer := WorldStreamer.new()
	streamer.field = a
	add_child(streamer)
	await _settle(streamer, Vector3(0, 12, 0))
	_check(streamer.metrics().horizontal_regions == 9 and streamer.active.size() < 27, "3x3 horizontal sparse Y")
	var first_plans := streamer.plan_requests
	for x: float in [63.9, 64.1, 63.8, 64.2]:
		streamer.update_target(Vector3(x, 12, 0), 0.25)
	_check(streamer.plan_requests == first_plans, "boundary hysteresis no thrash")
	await _settle(streamer, Vector3(74, 12, 0))
	_check(streamer.center.x == 1 and streamer.metrics().horizontal_regions == 9 and streamer.unloaded > 0, "crossing applies/unloads")
	await _settle(streamer, Vector3(74, 140, 0))
	_check(streamer.center.y == 2 and streamer.active.has(Vector3i(1, 2, 0)), "vertical player chunk")
	_check(streamer.active.has(Vector3i(1, 0, 0)), "surface kept without dense vertical cube")
	await _settle(streamer, Vector3(0, 12, 0))
	_check(streamer.center == Vector3i.ZERO and streamer.metrics().horizontal_regions == 9, "return no duplication/loss")
	print("WORLD_FOUNDATION ", "PASS" if failures == 0 else "FAIL", " samples=", samples, " changed=", changed, " residency=", streamer.metrics())
	get_tree().quit(0 if failures == 0 else 1)
