extends Node
var failures := 0
class FreshWater extends WorldWater:
	func sample(_point: Vector3) -> Dictionary:
		return {"kind":"lake","depth":2,"level":1,"submerged":false,"current":Vector3.ZERO}

func check(ok: bool,label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	var grid := WaterGrid.new()
	grid.tuning.tile_metres = 8
	grid.tuning.cell_metres = 1
	var dam := [true]
	grid.height_sample = func(point: Vector3) -> float: return 4.0 if dam[0] and point.x >= 4 else 0.0
	var tile := grid.ensure_tile(Vector2i.ZERO)
	grid.add_water(Vector3(2,0,3),8)
	for tick: int in 600:
		grid.step(1.0/15)
	check(tile.depth[3*8+6] == 0,"terrain dam holds")
	dam[0] = false
	check(grid.invalidate(AABB(Vector3(4,-1,0),Vector3(4,8,8))) <= 32,"local invalidation")
	for tick: int in 300:
		grid.step(1.0/15)
	check(tile.depth[3*8+6] > 0,"opened terrain redistributes")
	check(absf(grid.volume()-8) < .001,"dam release conserves")
	var inventory := InventoryState.new()
	inventory.add_item("bi.tool.watering_can",1)
	var uid: String = inventory.slot_at(0).stack_uid
	check(WaterContainer.volume(inventory,uid) == 0,"legacy missing module migrates to empty")
	check(WaterContainer.refill(inventory,uid,FreshWater.new(),Vector3.ZERO,Vector3.ONE) == OK,"freshwater refill")
	var ledger := SurfaceLedger.new()
	var farms := FarmSystem.new(ledger)
	farms.till(Vector3.ZERO,true,1)
	var key: String = farms.plots.keys()[0]
	check(WaterContainer.water_plot(inventory,uid,farms,key) == OK and WaterContainer.volume(inventory,uid) == 7,"watering consumes finite volume")
	var restored := InventoryState.new()
	check(restored.restore(JSON.parse_string(JSON.stringify(inventory.snapshot()))) == OK and WaterContainer.volume(restored,uid) == 7,"can module persists with existing inventory schema")
	var motion := WaterMotion.new()
	var body := CharacterBody3D.new()
	add_child(body)
	motion.apply(body,{"depth":3,"level":2,"current":Vector3(100,0,0)},.1,grid.tuning)
	check(motion.swimming and body.velocity.x > 0 and body.velocity.x <= grid.tuning.max_current,"bounded current/swim")
	motion.apply(body,{"depth":0,"level":-2,"current":Vector3.ZERO},.1,grid.tuning)
	check(not motion.swimming,"exit water")
	body.position = Vector3(0,0,0)
	body.velocity = Vector3.ZERO
	for tick: int in 600:
		motion.apply(body,{"depth":5,"level":2,"current":Vector3.ZERO},1.0/60,grid.tuning)
		body.position += body.velocity/60
	check(absf(body.position.y-(2-float(grid.tuning.float_offset))) < .03,"buoyancy converges without gravity bias")
	body.queue_free()
	_saved_water()
	_edges()
	print("R3_WATER_B ","PASS" if failures == 0 else "FAIL"," failures=",failures)
	get_tree().quit(1 if failures else 0)

func _saved_water() -> void:
	var root := "user://qa_r3_water/"+Crypto.new().generate_random_bytes(8).hex_encode()
	var identity := {"save_id":"33333333333333333333333333333333","world_seed":424242,"world_generation_version":2,"world_profile":WorldGenerationProfile.ID}
	var store := BufferedWorldDeltaStore.new(root,identity)
	check(store.load_world() == OK,"terrain store opens")
	var adapter := VoxelTerrainAdapter.new()
	adapter.field = WorldFieldV2.new(424242)
	adapter.deltas = store
	var domain := WaterDomain.new()
	domain.configure(adapter)
	check(domain.open_save(root,identity.save_id) == OK,"old R2 world without water document reconstructs")
	var lake := adapter.field.lake_body()
	var point := domain.grid.point_at(domain.grid.cell_at(Vector3(lake.center.x,0,lake.center.y)))
	domain.ensure_near(point)
	var initial := domain.grid.sample(point)
	var removed := {}
	var origin := WorldCoordinates.world_to_voxel(Vector3(point.x,initial.level-initial.depth-1.5,point.z))
	for y: int in 5:
		removed[origin+Vector3i(0,y,0)] = {"density":1000,"materials":[0,0,15,0]}
	check(store.stage(removed) == OK,"sparse terrain alteration")
	domain.invalidate(AABB(Vector3(point.x-.2,initial.level-5,point.z-.2),Vector3(.4,10,.4)))
	domain.grid.add_water(point,2)
	var expected := domain.grid.sample(point)
	check(domain.flush() == ERR_BUSY,"water cannot checkpoint ahead of dirty terrain")
	check(store.flush() == OK and domain.flush() == OK,"ordered terrain then water commit")
	var saved_volume := domain.grid.volume()
	var reload_store := BufferedWorldDeltaStore.new(root,identity)
	check(reload_store.load_world() == OK,"terrain reopened")
	var restored_adapter := VoxelTerrainAdapter.new()
	restored_adapter.field = adapter.field
	restored_adapter.deltas = reload_store
	var reload := WaterDomain.new()
	reload.configure(restored_adapter)
	check(reload.open_save(root,identity.save_id) == OK,"water reopened")
	reload.ensure_near(point)
	var actual := reload.grid.sample(point)
	check(is_equal_approx(actual.depth,expected.depth) and is_equal_approx(actual.level,expected.level),"terrain and meaningful water outcome reload together")
	check(absf(reload.grid.volume()-saved_volume) < .01,"save/reload no water duplication")
	reload.free()
	domain.free()
	restored_adapter.free()
	adapter.free()

func _edges() -> void:
	var coast := WaterGrid.new()
	coast.tuning.tile_metres = 8
	coast.tuning.cell_metres = 1
	coast.height_sample = func(_p: Vector3) -> float: return -1
	coast.initial_water = func(p: Vector3) -> Dictionary: return {"kind":"ocean" if p.x < 4 else "dry","level":0.0}
	coast.ensure_tile(Vector2i.ZERO).wake()
	coast.step(1.0/15)
	check(coast.sample(Vector3(4.5,0,3.5)).kind == "ocean","coastal inflow cannot become freshwater")
	var fall := WaterGrid.new()
	fall.tuning.tile_metres = 8
	fall.tuning.cell_metres = 1
	fall.height_sample = func(p: Vector3) -> float: return 4.0 if p.x < 4 else 0.0
	fall.add_water(Vector3(3,0,3),2)
	fall.step(1.0/15)
	check(not fall.waterfalls.is_empty(),"height discontinuity produces semantic waterfall")
