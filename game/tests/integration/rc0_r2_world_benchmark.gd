extends "res://tests/integration/rc0_r2_benchmark.gd"
## QA: production v2 terrain/profile/components with the matched P03 camera.
func _ready() -> void:
	super()
	var field := WorldFieldV2.new(424242)
	baseline.terrain.field = field
	baseline.terrain.generator = field.graph
	baseline.terrain.native.voxel_bounds = AABB(Vector3(-2048,-512,-2048),Vector3(4096,1024,4096))
	baseline.terrain.native.stream.base = field.graph
	baseline.terrain.native.generator = field.graph
	baseline.streamer.field = field
	surface.field = PropField.new(field)
	var identity := {"save_id":"33333333333333333333333333333333","world_seed":424242,"world_generation_version":2,"world_profile":field.profile_id}
	var store := BufferedWorldDeltaStore.new("user://qa_r2_v2_bench/"+Crypto.new().generate_random_bytes(6).hex_encode(),identity)
	assert(store.load_world() == OK)
	surface.session.store = store
	surface.session.edits.store = store
	baseline.terrain.deltas = store
	baseline.terrain.native.stream.deltas = store
	saver.store = store
	baseline.get_node("WorldSession/Lake").visible = false
	var water_view := GeneratedWaterView.new()
	water_view.field = field
	baseline.add_child(water_view)
	WorldBoundary.configure_field(field)
	print("R2_V2_BENCH ",field.metadata)
func prepare_dense() -> Dictionary:
	var field: IslandField = baseline.terrain.field
	for z: int in [30,40,50,60,70,80,90,100,-30,-40,-50,-60,-70,-80,-90,-100]:
		for x: int in [-90,-80,-70,-60,-50,-40,-30,-20,-10,0,10,20,30,40,50,60]:
			var height := field.top_surface(x,z)
			if height < 6 or field.forest_weight(Vector3(x,height,z)) < .4:
				continue
			var valid := true
			for offset: int in range(0,36,3):
				var top := field.top_surface(x+offset,z)
				if absf(top-height) > 6:
					valid = false
					break
			if valid and _route_clear(field,x,z):
				baseline.place(Vector3(x,height+3,z))
				return {"start":[x,height,z],"route_length":35,"max_height_delta":6}
	return {"error":"no traversable forest route"}

func _route_clear(field: IslandField, x: int, z: int) -> bool:
	var props := PropField.new(field)
	for pz: int in range(floori((z-2)/16.0),floori((z+2)/16.0)+1):
		for px: int in range(floori((x-2)/16.0),floori((x+37)/16.0)+1):
			for row: Dictionary in props.candidates(Vector2i(px,pz),false):
				if row.point[0] >= x-2 and row.point[0] <= x+37 and absf(float(row.point[2])-z) < .85:
					return false
	return true
