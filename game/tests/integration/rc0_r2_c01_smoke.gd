extends Node
var failures := 0
func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("RC0_R2_C01 "+label)
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	var signatures: Dictionary = {}
	var rivers := 0
	var first: WorldFieldV2 = null
	for seed_value: int in [424242,12345,8675309]:
		var field := WorldFieldV2.new(seed_value)
		if first == null:
			first = field
		check(field.graph is VoxelGeneratorGraph and field.graph.use_xz_caching and field.graph.use_optimized_execution_map and field.graph.use_subdivision,"native optimized production graph")
		check(field.metadata.land_area_m2 > 500000 and field.metadata.land_area_m2 < 750000,"roughly4x original land area")
		check(field.metadata.lowland_ratio > .5 and field.metadata.highland_ratio > .15,"broad lowlands and highlands")
		check(field.lakes.size() in [1,2] and field.village_candidates.size() > 10,"hydrology/village candidates")
		for body: Dictionary in field.lakes:
			check(field.density(Vector3(body.center[0],body.level,body.center[1])) > 0,"lake carved below water")
			check(body.depth/float(field.profile.elevation_step) in [1.0,2.0,3.0],"lake depth logical bands")
		for candidate: Dictionary in field.village_candidates:
			check(candidate.contiguous_area_m2 >= 1200 and candidate.steepness_degrees <= 9 and candidate.flood_risk == 0,"sampled contiguous village footprint")
		if not field.river.is_empty():
			rivers += 1
			var previous := INF
			for point: Array in field.river.points:
				check(float(point[1]) <= previous,"river high -> low")
				previous = point[1]
			check(field.river.reaches_sea,"river reaches sea")
		var buffer := VoxelBuffer.new()
		buffer.create(16,16,16)
		field.graph.generate_block(buffer,Vector3(128,48,128),0)
		signatures[seed_value] = buffer.get_channel_as_byte_array(VoxelBuffer.CHANNEL_SDF).hex_encode()
		check(is_equal_approx(field.top_surface(0,0),8) and field.top_surface(780,0) < -100,"flat spawn and deep ocean %s/%s"%[field.top_surface(0,0),field.top_surface(780,0)])
		check(WorldGenerationProfile.supported(2,field.profile_id) and not WorldGenerationProfile.supported(999,field.profile_id),"generator identity/future reject")
	check(rivers >= 1 and signatures.values()[0] != signatures.values()[1],"materially different layouts with river variant")
	var repeat := WorldFieldV2.new(424242)
	check(AtomicDocument.same_value(first.lakes,repeat.lakes) and AtomicDocument.same_value(first.village_candidates,repeat.village_candidates),"deterministic metadata")
	var a := VoxelBuffer.new()
	var b := VoxelBuffer.new()
	a.create(16,16,16)
	b.create(16,16,16)
	first.graph.generate_block(a,Vector3(64,20,64),0)
	repeat.graph.generate_block(b,Vector3(64,20,64),0)
	check(a.get_channel_as_byte_array(VoxelBuffer.CHANNEL_SDF) == b.get_channel_as_byte_array(VoxelBuffer.CHANNEL_SDF),"deterministic native blocks")
	var coarse := VoxelBuffer.new()
	coarse.create(8,8,8)
	first.graph.generate_block(coarse,Vector3(64,20,64),1)
	for z: int in 8:
		for x: int in 8:
			for y: int in 8:
				var fine := a.get_voxel_f(x*2,y*2,z*2,VoxelBuffer.CHANNEL_SDF)
				if absf(fine) < .01:
					check(is_equal_approx(fine,coarse.get_voxel_f(x,y,z,VoxelBuffer.CHANNEL_SDF)),"shared LOD surface SDF")
	_legacy()
	_delta_stream(first)
	print("RC0_R2_C01 ","PASS" if failures == 0 else "FAIL"," failures=",failures)
	get_tree().quit(1 if failures else 0)
func _legacy() -> void:
	var field := IslandField.new(424242)
	var builder := NativeTerrainGraph.new()
	check(builder.build_legacy(field).success,"legacy native graph compilation")
	var buffer := VoxelBuffer.new()
	buffer.create(16,16,16)
	builder.generator.generate_block(buffer,Vector3(40,16,40),0)
	for z: int in 16:
		for x: int in 16:
			for y: int in 16:
				var point := Vector3(x+40,y+16,z+40)*.5
				var expected := clampf(field.density(point)*2,-8,8)
				check(absf(expected-buffer.get_voxel_f(x,y,z,VoxelBuffer.CHANNEL_SDF)) < .02,"legacy SDF16 field preserved")
func _delta_stream(field: WorldFieldV2) -> void:
	var root := "user://qa_r2_c01/"+Crypto.new().generate_random_bytes(8).hex_encode()
	var identity := {"save_id":"22222222222222222222222222222222","created_at":"2026-10-30T00:00:00Z","world_seed":424242,"world_generation_version":2,"world_profile":field.profile_id}
	var store := WorldDeltaStore.new(root,identity)
	check(store.load_world() == OK,"sparse world load")
	check(store.commit({Vector3i(0,16,0):{"density":1234,"materials":[0,0,15,0]}}) == OK,"delta durable checkpoint")
	var reload := WorldDeltaStore.new(root,identity)
	check(reload.load_world() == OK,"delta reload")
	var stream := VoxelDeltaStream.new()
	stream.base = field.graph
	stream.deltas = reload
	var buffer := VoxelBuffer.new()
	buffer.create(16,16,16)
	check(stream._load_voxel_block(buffer,Vector3i(0,1,0),0) == VoxelStream.RESULT_BLOCK_FOUND,"changed data through native stream")
	check(buffer.get_voxel(0,0,0,VoxelBuffer.CHANNEL_SDF) == 1234,"exact saved SDF preserved")
	check(stream._load_voxel_block(buffer,Vector3i(5,5,5),0) == VoxelStream.RESULT_BLOCK_NOT_FOUND,"untouched blocks fall through to graph")
	var wrong := identity.duplicate(true)
	wrong.world_generation_version = 1
	check(WorldDeltaStore.new(root,wrong).load_world() != OK,"old save never silently reinterpreted")
