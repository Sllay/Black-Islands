extends Node
var failures := 0
func check(ok: bool,label: String) -> void:
	if not ok:
		failures += 1
		push_error(label)
func _ready() -> void:
	var grid := WaterGrid.new()
	grid.tuning.tile_metres = 8
	grid.tuning.cell_metres = 1
	grid.height_sample = func(_point: Vector3) -> float: return 0
	var tile := grid.ensure_tile(Vector2i.ZERO)
	grid.add_water(Vector3(3,0,3),8)
	var volume := grid.volume()
	for tick: int in 3000:
		grid.step(1.0/15)
	check(absf(grid.volume()-volume) < .001,"closed basin conserves volume")
	check(tile.activity == WaterTile.Activity.SLEEPING,"basin settles and sleeps")
	grid.step(1.0/15)
	check(grid.last_cells == 0,"sleeping solves zero cells")
	check(grid.add_water(Vector3(2,0,2),1) == OK and tile.activity == WaterTile.Activity.ACTIVE,"external volume wakes")
	var slope := WaterGrid.new()
	slope.tuning.tile_metres = 8
	slope.tuning.cell_metres = 1
	slope.height_sample = func(point: Vector3) -> float: return -point.x*.2
	slope.ensure_tile(Vector2i.ZERO)
	slope.add_water(Vector3(2,0,2),4)
	slope.step(1.0/15)
	check(slope.sample(Vector3(2,0,2)).current.x > 0,"downhill current from solver")
	check(absf(slope.volume()-4) < .001,"slope conserves volume")
	var adapter := VoxelTerrainAdapter.new()
	adapter.field = WorldFieldV2.new(424242)
	var domain := WaterDomain.new()
	domain.configure(adapter)
	var lake := adapter.field.lake_body()
	var center := Vector3(lake.center.x,float(lake.level)-1,lake.center.y)
	domain.ensure_near(center)
	check(domain.grid.sample(center).depth > 0,"R2 hydrology initializes inland domain")
	var again := WaterDomain.new()
	again.configure(adapter)
	again.ensure_near(center)
	check(again.grid.volume() == domain.grid.volume(),"seed reconstruction deterministic")
	check(domain.grid.tiles.size() <= 9,"ocean not globally allocated")
	domain.free()
	again.free()
	adapter.free()
	print("R3_WATER_A ","PASS" if failures == 0 else "FAIL"," failures=",failures," ",grid.report())
	get_tree().quit(1 if failures else 0)
