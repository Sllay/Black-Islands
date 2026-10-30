class_name WaterGrid
extends RefCounted
## Conservative explicit surface relaxation. Closed unloaded boundaries; ocean
## exchange is counted separately. No scene/render/physics dependency.
const DIRECTIONS := [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.DOWN,Vector2i.UP]
var tuning: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/water/tuning.json"))
var tiles: Dictionary = {}
var height_sample: Callable
var initial_water: Callable
var waterfalls: Array[Dictionary] = []
var sources: Dictionary = {}
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
			tile.rest_level[i] = float(water.level)
			tile.kind[i] = 2 if water.kind == "ocean" and tile.ground[i] < 0 else (3 if water.kind == "river" else (1 if water.kind == "lake" else 0))
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
	return {"kind":"dry" if tile.depth[i] <= tuning.dry_depth else ("ocean" if tile.kind[i] in [2,4] else ("river" if tile.kind[i] == 3 else "lake")),"level":level,"depth":tile.depth[i],"submerged":point.y < level and tile.depth[i] > tuning.dry_depth,"current":current,"grid_cell":cell,"tile":coord}
func add_water(point: Vector3, cubic_metres: float) -> Error:
	if not point.is_finite() or not is_finite(cubic_metres) or cubic_metres < 0:
		return ERR_INVALID_PARAMETER
	var cell := cell_at(point)
	var tile := ensure_tile(address(cell))
	tile.depth[index(cell)] += cubic_metres/(tuning.cell_metres*tuning.cell_metres)
	external_volume += cubic_metres
	dirty = true
	tile.revision += 1
	tile.wake()
	return OK
func remove_water(point: Vector3, cubic_metres: float) -> Error:
	if not point.is_finite() or not is_finite(cubic_metres) or cubic_metres < 0:
		return ERR_INVALID_PARAMETER
	var cell := cell_at(point)
	var tile: WaterTile = tiles.get(address(cell))
	if tile == null:
		return ERR_UNAVAILABLE
	var area := float(tuning.cell_metres)*float(tuning.cell_metres)
	var i := index(cell)
	if tile.depth[i]*area < cubic_metres:
		return ERR_UNAVAILABLE
	tile.depth[i] -= cubic_metres/area
	tile.revision += 1
	external_volume -= cubic_metres
	dirty = true
	tile.wake()
	return OK
func add_precipitation(area: AABB, metres: float) -> void:
	if not is_finite(metres) or metres <= 0:
		return
	for tile: WaterTile in tiles.values():
		for i: int in tile.depth.size():
			var cell := tile.coord*side()+Vector2i(i%side(),floori(i/float(side())))
			if Rect2(Vector2(area.position.x,area.position.z),Vector2(area.size.x,area.size.z)).has_point(Vector2(point_at(cell).x,point_at(cell).z)):
				add_water(point_at(cell),metres*tuning.cell_metres*tuning.cell_metres)
func invalidate(area: AABB) -> int:
	var first := cell_at(area.position)
	var last := cell_at(area.end)
	var count := 0
	for z: int in range(first.y,last.y+1):
		for x: int in range(first.x,last.x+1):
			var cell := Vector2i(x,z)
			var tile: WaterTile = tiles.get(address(cell))
			if tile == null:
				continue
			var i := index(cell)
			tile.ground[i] = height_sample.call(point_at(cell))
			tile.revision += 1
			tile.wake()
			count += 1
	dirty = dirty or count > 0
	return count
func step(dt: float) -> void:
	var start := Time.get_ticks_usec()
	last_cells = 0
	for cell: Vector2i in sources:
		var tile: WaterTile = tiles.get(address(cell))
		if tile == null or tile.activity == WaterTile.Activity.INACTIVE:
			continue
		var source: Dictionary = sources[cell]
		var i := index(cell)
		var amount := minf(float(source.rate)*dt/(tuning.cell_metres*tuning.cell_metres),maxf(0,float(source.level)-tile.ground[i]-tile.depth[i]))
		if amount > .000001:
			add_water(point_at(cell),amount*tuning.cell_metres*tuning.cell_metres)
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
	var n := side()
	var spacing := float(tuning.cell_metres)
	var factor := float(tuning.conductance)*dt
	var fraction := clampf(float(tuning.max_out_fraction),0,.249)
	var drop := float(tuning.waterfall_drop)
	for tile: WaterTile in active:
		tile.previous = tile.depth.duplicate()
		tile.flow_x.fill(0)
		tile.flow_z.fill(0)
		for i: int in tile.depth.size():
			last_cells += 1
			if tile.depth[i] <= tuning.dry_depth :
				continue
			var column := i%n
			var row := floori(i/float(n))
			var own_surface := tile.ground[i]+tile.depth[i]
			var limit := tile.depth[i]*fraction
			for d: int in 4:
				var direction: Vector2i = DIRECTIONS[d]
				var other := tile
				var j := i+direction.x+direction.y*n
				if column+direction.x < 0 or column+direction.x >= n or row+direction.y < 0 or row+direction.y >= n:
					other = tiles.get(tile.coord+direction)
					j = posmod(row+direction.y,n)*n+posmod(column+direction.x,n)
				if other == null or other.activity == WaterTile.Activity.INACTIVE:
					continue
				var head := own_surface-other.ground[j]-other.depth[j]
				if head <= 0:
					continue
				var amount := minf(head*factor,limit)
				if amount < 0.000001:
					continue
				if not participants.has(other.coord):
					participants[other.coord] = other
					other.change.fill(0)
					other.previous = other.depth.duplicate()
				if tile.kind[i] in [2,4] and other.kind[j] != 2:
					other.kind[j] = 4
				elif other.kind[j] == 0:
					other.kind[j] = 1
				tile.change[i] -= amount
				other.change[j] += amount
				var speed: float = amount*spacing/maxf(dt*tile.depth[i],.0001)
				tile.flow_x[i] += direction.x*speed
				tile.flow_z[i] += direction.y*speed
				if other.activity != WaterTile.Activity.ACTIVE:
					other.wake()
				if head >= drop and tile.ground[i]-other.ground[j] >= drop and waterfalls.size() < int(tuning.max_waterfalls):
					var cell := tile.coord*n+Vector2i(column,row)
					waterfalls.append({"from":point_at(cell)+Vector3.UP*own_surface,"to":point_at(cell+direction)+Vector3.UP*(other.ground[j]+other.depth[j]),"volume_per_second":amount*spacing*spacing/dt})
	for tile: WaterTile in participants.values():
		var maximum := 0.0
		var touched := false
		var fastest := 0.0
		for i: int in tile.depth.size():
			if tile.kind[i] == 2:
				var target := maxf(0,-tile.ground[i])
				external_volume += (target-tile.depth[i]-tile.change[i])*tuning.cell_metres*tuning.cell_metres
				tile.depth[i] = target
			else:
				tile.depth[i] = maxf(0,tile.depth[i]+tile.change[i])
			maximum = maxf(maximum,absf(tile.change[i]))
			fastest = maxf(fastest,Vector2(tile.flow_x[i],tile.flow_z[i]).length())
			touched = touched or absf(tile.change[i]) > .000001
		if touched:
			tile.revision += 1
			dirty = true
		if tile in active:
			tile.quiet = tile.quiet+1 if maximum < tuning.sleep_delta and fastest < tuning.sleep_current else 0
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
	return {"active_tiles":active,"sleeping_tiles":sleeping,"resident_tiles":tiles.size(),"inactive_tiles":tiles.size()-active-sleeping,"sources":sources.size(),"solver_cells":last_cells,"solver_ms":last_ms,"mean_ms":total_ms/maxi(1,steps),"worst_ms":worst_ms,"array_bytes":memory}
