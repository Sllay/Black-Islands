class_name WaterDomain
extends Node
## Single fixed-rate scheduler. WaterGrid is pure data and independent of FPS.
var grid := WaterGrid.new()
var terrain: VoxelTerrainAdapter
var accumulator := 0.0
var observer: Node3D
var _poll := 0.0
var candidates: Dictionary = {}
func configure(adapter: VoxelTerrainAdapter) -> void:
	terrain = adapter
	grid.height_sample = func(point: Vector3) -> float: return terrain.field.top_surface(point.x,point.z)
	grid.initial_water = _initial
	if terrain.field is WorldFieldV2:
		for lake: Dictionary in terrain.field.lakes:
			var center := Vector3(lake.center[0],0,lake.center[1])
			var radius := float(lake.radius)*1.5
			_mark_bounds(center-Vector3(radius,0,radius),center+Vector3(radius,0,radius))
		var points: Array = terrain.field.river.get("points",[])
		for i: int in range(points.size()-1):
			var a := Vector3(points[i][0],0,points[i][2])
			var b := Vector3(points[i+1][0],0,points[i+1][2])
			_mark_bounds(a.min(b)-Vector3.ONE*12,a.max(b)+Vector3.ONE*12)
	else:
		var lake := terrain.field.lake_body()
		_mark_bounds(Vector3(lake.center.x-lake.radius*1.5,0,lake.center.y-lake.radius*1.5),Vector3(lake.center.x+lake.radius*1.5,0,lake.center.y+lake.radius*1.5))
func _initial(point: Vector3) -> Dictionary:
	if terrain.field is WorldFieldV2:
		return terrain.field.water_at(Vector2(point.x,point.z))
	var lake := terrain.field.lake_body()
	return {"kind":"lake" if Vector2(point.x,point.z).distance_to(lake.center) < lake.radius*1.4 else "ocean","level":lake.level if Vector2(point.x,point.z).distance_to(lake.center) < lake.radius*1.4 else 0.0}
func _process(delta: float) -> void:
	_poll += delta
	if observer != null and _poll > .5:
		_poll = 0
		ensure_near(observer.global_position)
	accumulator = minf(accumulator+delta,.25)
	var dt := 1.0/float(grid.tuning.solver_hz)
	var count := 0
	while accumulator >= dt and count < 2:
		grid.step(dt)
		accumulator -= dt
		count += 1
func ensure_near(point: Vector3) -> void:
	var center := grid.address(grid.cell_at(point))
	for z: int in range(center.y-1,center.y+2):
		for x: int in range(center.x-1,center.x+2):
			var coord := Vector2i(x,z)
			if grid.tiles.has(coord):
				continue
			if candidates.has(coord):
				var tile := grid.ensure_tile(coord)
				if terrain.field is WorldFieldV2 and not terrain.field.river.is_empty():
					tile.wake()
func _mark_bounds(low: Vector3, high: Vector3) -> void:
	var first := grid.address(grid.cell_at(low))
	var last := grid.address(grid.cell_at(high))
	for z: int in range(first.y,last.y+1):
		for x: int in range(first.x,last.x+1):
			candidates[Vector2i(x,z)] = true

func invalidate(area: AABB) -> void:
	grid.invalidate(area.grow(float(grid.tuning.cell_metres)))
