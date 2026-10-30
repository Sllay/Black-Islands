extends Node
var failures := 0
func check(ok: bool,label: String) -> void:
	if not ok:
		failures += 1
		push_error("RC0_R2_C03 "+label)
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	check(GrassGeometry.cluster(3).surface_get_array_len(0) == 18 and GrassGeometry.cluster(1).surface_get_array_len(0) == 6,"3/2/1card native mesh LOD")
	check(GrassGeometry.cluster(3) == GrassGeometry.cluster(3),"cached mesh, no per-frame allocation")
	check(GrassGeometry.blade_texture().get_image().has_mipmaps(),"cutout alpha coverage mip chain")
	var ledger := SurfaceLedger.new()
	ledger.suppress(Vector3.ZERO,"cut")
	ledger.suppression[SurfaceLedger.cell_key(Vector3.ZERO)].foliage_only = true
	ledger.release(Vector3.ZERO,"cut")
	check(ledger.suppressed(Vector3.ZERO) and not ledger.suppressed(Vector3.ZERO,false),"cut affects grass, not persistent tree authority")
	var reload := SurfaceLedger.new()
	check(reload.restore(JSON.parse_string(JSON.stringify(ledger.snapshot()))) == OK and reload.suppressed(Vector3.ZERO),"compact suppression persists")
	reload.clock += SurfaceLedger.DAY*6
	check(not reload.suppressed(Vector3.ZERO),"regrowth restores eligibility")
	var field := PropField.new(IslandField.new(424242))
	var full := field.candidates(Vector2i(2,0))
	var resources := field.candidates(Vector2i(2,0),false)
	for row: Dictionary in resources:
		check(row in full,"resource stable IDs unaffected by native decoration")
	var bench: Node3D = load("res://scenes/debug/Rc0R2Benchmark.tscn").instantiate()
	add_child(bench)
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec()-started < 25000:
		if bench.baseline.pawn.spawned and bench.surface.foliage.patches.size() == 9 and bench.surface.foliage.native_foliage.instancer.debug_get_instance_counts().get(1,0) > 500:
			break
		await get_tree().process_frame
	var foliage: FoliagePresenter = bench.surface.foliage
	check(foliage.patches.size() <= 9 and foliage.patches.size() > 0,"bounded64m resource regions")
	check(foliage.native_foliage.instancer.get_parent() == bench.baseline.terrain.native,"real VoxelInstancer child of native terrain")
	var stats := foliage.report()
	check(stats.native_instances.get(1,0) > 500,"native grass emitted on actual terrain")
	check(stats.resource_batches < 70 and foliage.actors.size() < 100,"bounded batches and near-only collision adapters")
	var item: VoxelInstanceLibraryMultiMeshItem = foliage.native_foliage.instancer.library.get_item(1)
	check(item.lod_index == 0 and item.mesh_lod2 != null and item.generator.voxel_texture_filter_enabled and item.generator.snap_to_generator_sdf_enabled,"native LOD/slope/material/series filters")
	var point: Vector3 = bench.baseline.pawn.global_position+Vector3(2,0,0)
	foliage.cut(point,1.4)
	foliage.native_foliage._process(.2)
	check(bench.surface.ledger.suppression.size() > 0,"attack cut creates local suppression")
	print("R2_C03_NATIVE ",JSON.stringify(stats))
	bench.queue_free()
	await get_tree().process_frame
	print("RC0_R2_C03 ","PASS" if failures == 0 else "FAIL"," failures=",failures)
	get_tree().quit(1 if failures else 0)
