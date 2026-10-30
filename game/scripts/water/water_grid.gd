class_name WaterGrid
extends RefCounted
## Conservative explicit surface relaxation. Closed unloaded boundaries; ocean
## exchange is counted separately. No scene/render/physics dependency.
const DIRECTIONS := [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]
var tuning: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/water/tuning.json"))
var tiles: Dictionary = {}
var height_sample: Callable
var initial_water: Callable
var sources: Dictionary = {}
var waterfalls: Array[Dictionary] = []
var steps := 0
var last_cells := 0
var last_ms := 0.0
var total_ms := 0.0
var worst_ms := 0.0
var external_volume := 0.0
var _cursor := 0
var dirty := false
func side() -> int:
	return roundi(float(tuning.tile_metres)/float(tuning.cell_metres))
func cell_at(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x/tuning.cell_metres),floori(point.z/tuning.cell_metres))
func address(cell: Vector2i) -> Vector2i:
	return Vector2i(floori(cell.x/float(side())),floori(cell.y/float(side())))
func point_at(cell: Vector2i) -> Vector3:
	return Vector3((cell.x+.5)*tuning.cell_metres,0,(cell.y+.5)*tuning.cell_metres)
func index(cell: Vector2i) -> int:
	return posmod(cell.y,side())*side()+posmod(cell.x,side())
func ensure_tile(coord: Vector2i) -> WaterTile:
	if tiles.has(coord):
		return tiles[coord]
	var tile := WaterTile.new(coord,side())
	for z: int in side():
		for x: int in side():
			var cell := coord*side()+Vector2i(x,z)
			var i := z*side()+x
			var point := point_at(cell)
			tile.ground[i] = height_sample.call(point) if height_sample.is_valid() else 0
			var water: Dictionary = {"kind":"dry","level":0}
			if initial_water.is_valid():
				water = initial_water.call(point)
			tile.kind[i] = 2 if water.kind == "ocean" and tile.ground[i] < 0 else (1 if water.kind in ["lake","river"] else 0)
			tile.depth[i] = maxf(0,float(water.level)-tile.ground[i]) if tile.kind[i] != 0 else 0.0
			tile.previous[i] = tile.depth[i]
	tiles[coord] = tile
	return tile
func sample(point: Vector3) -> Dictionary:
	var cell := cell_at(point)
	var coord := address(cell)
	if not tiles.has(coord):
		return {}
	var tile: WaterTile = tiles[coord]
	var i := index(cell)
	var level := tile.ground[i]+tile.depth[i]
	var current := Vector3(tile.flow_x[i],0,tile.flow_z[i]).limit_length(tuning.max_current)
	return {"kind":"dry" if tile.depth[i] <= tuning.dry_depth else ("ocean" if tile.kind[i] == 2 else "lake"),"level":level,"depth":tile.depth[i],"submerged":point.y < level and tile.depth[i] > tuning.dry_depth,"current":current,"grid_cell":cell,"tile":coord}
func add_water(point: Vector3, cubic_metres: float) -> Error:
	if not point.is_finite() or not is_finite(cubic_metres) or cubic_metres < 0:
		return ERR_INVALID_PARAMETER
	var cell := cell_at(point)
	var tile := ensure_tile(address(cell))
	tile.depth[index(cell)] += cubic_metres/(tuning.cell_metres*tuning.cell_metres)
	external_volume += cubic_metres
	dirty = true
	tile.wake()
	return OK
func add_precipitation(area: AABB, metres: float) -> void:
	if not is_finite(metres) or metres <= 0:
		return
	for tile: WaterTile in tiles.values():
		for i: int in tile.depth.size():
			var cell := tile.coord*side()+Vector2i(i%side(),floori(i/float(side())))
			if area.has_point(point_at(cell)):
				add_water(point_at(cell),metres*tuning.cell_metres*tuning.cell_metres)
func invalidate(area: AABB) -> int:
	var count := 0
	for tile: WaterTile in tiles.values():
		var changed := false
		for i: int in tile.depth.size():
			var cell := tile.coord*side()+Vector2i(i%side(),floori(i/float(side())))
			var point := point_at(cell)
			if point.x < area.position.x or point.x > area.end.x or point.z < area.position.z or point.z > area.end.z:
				continue
			tile.ground[i] = height_sample.call(point)
			count += 1
			changed = true
		if changed:
			tile.wake()
			dirty = true
	return count
func step(dt: float) -> void:
	var start := Time.get_ticks_usec()
	last_cells = 0
	waterfalls.clear()
	var active: Array[WaterTile] = []
	var keys := tiles.keys()
	keys.sort()
	if not keys.is_empty():
		for offset: int in keys.size():
			var tile: WaterTile = tiles[keys[(_cursor+offset)%keys.size()]]
			if tile.activity == WaterTile.Activity.ACTIVE and active.size() < int(tuning.max_active_tiles):
				active.append(tile)
		_cursor = (_cursor+int(tuning.max_active_tiles))%keys.size()
	var participants: Dictionary = {}
	for tile: WaterTile in active:
		participants[tile.coord] = tile
		tile.change.fill(0)
	for tile: WaterTile in active:
		tile.previous = tile.depth.duplicate()
		tile.flow_x.fill(0)
		tile.flow_z.fill(0)
		for i: int in tile.depth.size():
			last_cells += 1
			if tile.depth[i] <= tuning.dry_depth :
				continue
			var cell := tile.coord*side()+Vector2i(i%side(),floori(i/float(side())))
			for direction: Vector2i in DIRECTIONS:
				var next := cell+direction
				var other: WaterTile = tiles.get(address(next))
				if other == null:
					continue
				var j := index(next)
				var head := tile.ground[i]+tile.depth[i]-(other.ground[j]+other.depth[j])
				if head <= 0:
					continue
				var amount := minf(head*tuning.conductance*dt,tile.depth[i]*tuning.max_out_fraction)
				if amount < 0.000001:
					continue
				if not participants.has(other.coord):
					participants[other.coord] = other
					other.change.fill(0)
					other.previous = other.depth.duplicate()
				tile.change[i] -= amount
				other.change[j] += amount
				var speed: float = amount*tuning.cell_metres/maxf(dt*tile.depth[i],.0001)
				tile.flow_x[i] += direction.x*speed
				tile.flow_z[i] += direction.y*speed
				if other.activity != WaterTile.Activity.ACTIVE:
					other.wake()
				if tile.ground[i]-other.ground[j] >= tuning.waterfall_drop and waterfalls.size() < 32:
					waterfalls.append({"from":point_at(cell)+Vector3.UP*(tile.ground[i]+tile.depth[i]),"to":point_at(next)+Vector3.UP*(other.ground[j]+other.depth[j]),"volume_per_second":amount*tuning.cell_metres*tuning.cell_metres/dt})
	for tile: WaterTile in participants.values():
		var maximum := 0.0
		var touched := false
		for i: int in tile.depth.size():
			if tile.kind[i] == 2:
				var target := maxf(0,-tile.ground[i])
				external_volume += (target-tile.depth[i]-tile.change[i])*tuning.cell_metres*tuning.cell_metres
				tile.depth[i] = target
			else:
				tile.depth[i] = maxf(0,tile.depth[i]+tile.change[i])
			maximum = maxf(maximum,absf(tile.change[i]))
			touched = touched or absf(tile.change[i]) > .000001
		if touched:
			tile.revision += 1
			dirty = true
		if tile in active:
			tile.quiet = tile.quiet+1 if maximum < tuning.sleep_delta else 0
			if tile.quiet >= int(tuning.sleep_steps):
				tile.activity = WaterTile.Activity.SLEEPING
				tile.flow_x.fill(0)
				tile.flow_z.fill(0)
	steps += 1
	last_ms = (Time.get_ticks_usec()-start)/1000.0
	total_ms += last_ms
	worst_ms = maxf(worst_ms,last_ms)
func volume() -> float:
	var total := 0.0
	for tile: WaterTile in tiles.values():
		for depth: float in tile.depth:
			total += depth*tuning.cell_metres*tuning.cell_metres
	return total
func report() -> Dictionary:
	var active := 0
	var sleeping := 0
	var memory := 0
	for tile: WaterTile in tiles.values():
		active += int(tile.activity == WaterTile.Activity.ACTIVE)
		sleeping += int(tile.activity == WaterTile.Activity.SLEEPING)
		memory += tile.bytes_used()
	return {"active_tiles":active,"sleeping_tiles":sleeping,"resident_tiles":tiles.size(),"solver_cells":last_cells,"solver_ms":last_ms,"mean_ms":total_ms/maxi(1,steps),"worst_ms":worst_ms,"array_bytes":memory}
