class_name WaterDomain
extends Node
## Single fixed-rate scheduler. WaterGrid is pure data and independent of FPS.
var grid := WaterGrid.new()
var terrain: VoxelTerrainAdapter
var accumulator := 0.0
var observer: Node3D
var _poll := 0.0
var candidates: Dictionary = {}
var terrain_store: WorldDeltaStore
var document: AtomicDocument
var _save_tick := 0.0
var last_save_error := OK
var last_invalidation_cells := 0
var source_cell := Vector2i(2147483647,2147483647)
func configure(adapter: VoxelTerrainAdapter) -> void:
	terrain = adapter
	terrain_store = adapter.deltas
	grid.height_sample = _height
	grid.initial_water = _initial
	if terrain.field is WorldFieldV2:
		for lake: Dictionary in terrain.field.lakes:
			var center := Vector3(lake.center[0],0,lake.center[1])
			var radius := float(lake.radius)*1.5
			_mark_bounds(center-Vector3(radius,0,radius),center+Vector3(radius,0,radius))
		var points: Array = terrain.field.river.get("points",[])
		if not points.is_empty():
			source_cell = grid.cell_at(Vector3(points[0][0],0,points[0][2]))
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
	_save_tick += delta
	if _save_tick > 4:
		_save_tick = 0
		last_save_error = flush()
	_poll += delta
	if observer != null and _poll > .5:
		_poll = 0
		ensure_near(observer.global_position,1)
	accumulator = minf(accumulator+delta,.25)
	var dt := 1.0/float(grid.tuning.solver_hz)
	var count := 0
	while accumulator >= dt and count < 2:
		grid.step(dt)
		accumulator -= dt
		count += 1
func ensure_near(point: Vector3, new_budget: int = 9) -> void:
	var center := grid.address(grid.cell_at(point))
	var radius := int(grid.tuning.resident_radius)
	for tile: WaterTile in grid.tiles.values():
		var distance := maxi(absi(tile.coord.x-center.x),absi(tile.coord.y-center.y))
		if distance > radius+1:
			tile.activity = WaterTile.Activity.INACTIVE
		elif distance <= radius and tile.activity == WaterTile.Activity.INACTIVE:
			tile.wake()
	var created := 0
	for z: int in range(center.y-radius,center.y+radius+1):
		for x: int in range(center.x-radius,center.x+radius+1):
			var coord := Vector2i(x,z)
			if grid.tiles.has(coord) or not candidates.has(coord) or created >= new_budget:
				continue
			var tile := grid.ensure_tile(coord)
			created += 1
			if tile.kind.has(3):
				tile.wake()
	# Analytic upstream boundary feeds the resident river corridor. This is
	# explicit external volume, never an unaccounted conservation exception.
	grid.sources.clear()
	for tile: WaterTile in grid.tiles.values():
		if tile.activity == WaterTile.Activity.INACTIVE or not tile.kind.has(3):
			continue
		var best := -INF
		var entry := Vector2i.ZERO
		for i: int in tile.depth.size():
			if tile.kind[i] != 3 or tile.depth[i] <= grid.tuning.dry_depth:
				continue
			var cell := tile.coord*tile.side+Vector2i(i%tile.side,floori(i/float(tile.side)))
			var boundary := cell == source_cell
			for direction: Vector2i in WaterGrid.DIRECTIONS:
				var neighbor: WaterTile = grid.tiles.get(grid.address(cell+direction))
				boundary = boundary or neighbor == null or neighbor.activity == WaterTile.Activity.INACTIVE
			if not boundary:
				continue
			var level := float(_initial(grid.point_at(cell)).level)
			if level > best:
				best = level
				entry = cell
		if is_finite(best):
			grid.sources[entry] = {"rate":float(grid.tuning.river_source_m3_s),"level":best}
func _mark_bounds(low: Vector3, high: Vector3) -> void:
	var first := grid.address(grid.cell_at(low))
	var last := grid.address(grid.cell_at(high))
	for z: int in range(first.y,last.y+1):
		for x: int in range(first.x,last.x+1):
			candidates[Vector2i(x,z)] = true

func invalidate(area: AABB) -> void:
	var first := grid.address(grid.cell_at(area.position))
	var last := grid.address(grid.cell_at(area.end))
	for z: int in range(first.y,last.y+1):
		for x: int in range(first.x,last.x+1):
			var coord := Vector2i(x,z)
			if candidates.has(coord) or (_initial(area.position).kind == "ocean" and _height(area.position) < 1):
				grid.ensure_tile(coord)
	last_invalidation_cells = grid.invalidate(area.grow(float(grid.tuning.cell_metres)))
func _height(point: Vector3) -> float:
	var base := terrain.field.top_surface(point.x,point.z)
	if not is_finite(base):
		base = -160
	if terrain_store == null:
		return base
	var origin := WorldCoordinates.world_to_voxel(Vector3(point.x,base-float(grid.tuning.height_scan_down),point.z))
	var scan := ceili((float(grid.tuning.height_scan_down)+float(grid.tuning.height_scan_up))/WorldCoordinates.VOXEL_SIZE)+1
	var patch := terrain_store.snapshot_box(origin,Vector3i(1,scan,1))
	if patch.is_empty():
		return base
	for offset: int in range(scan-1,-1,-1):
		var voxel := origin+Vector3i(0,offset,0)
		var position := WorldCoordinates.voxel_to_world(voxel)
		var sdf: float = DensityCodec.metres(patch[voxel].density) if patch.has(voxel) else terrain.field.density(position)
		if sdf < 0:
			return position.y+.25
	return base-float(grid.tuning.height_scan_down)

func open_save(directory: String, world_id: String) -> Error:
	document = AtomicDocument.new(directory.path_join("water.json"),1,{"world_id":world_id,"water_model":1,"cell_metres":grid.tuning.cell_metres,"tile_metres":grid.tuning.tile_metres})
	var error := document.read()
	if error != OK:
		return error
	var records: Variant = document.loaded.get("tiles",[])
	if not records is Array or records.size() > int(grid.tuning.max_saved_tiles):
		return ERR_FILE_CORRUPT
	for record: Variant in records:
		if not record is Dictionary or not record.get("coord") is Array or record.coord.size() != 2 or not record.get("depth") is String:
			return ERR_FILE_CORRUPT
		for axis: Variant in record.coord:
			if not (axis is float or axis is int) or not is_finite(float(axis)) or float(axis) != int(axis) or absf(axis) > 100000:
				return ERR_FILE_CORRUPT
		var tile := grid.ensure_tile(Vector2i(record.coord[0],record.coord[1]))
		var bytes := Marshalls.base64_to_raw(record.depth)
		if bytes.size() != tile.depth.size()*4:
			return ERR_FILE_CORRUPT
		tile.depth = bytes.to_float32_array()
		for depth: float in tile.depth:
			if not is_finite(depth) or depth < 0:
				return ERR_FILE_CORRUPT
		if record.has("kind"):
			var kinds := Marshalls.base64_to_raw(record.kind)
			if kinds.size() != tile.kind.size():
				return ERR_FILE_CORRUPT
			tile.kind = kinds
			for kind: int in tile.kind:
				if kind > 4:
					return ERR_FILE_CORRUPT
		tile.previous = tile.depth.duplicate()
		tile.revision = 1
		tile.wake()
	grid.external_volume = float(document.loaded.get("external_volume",0))
	return OK
func flush() -> Error:
	if document == null or not grid.dirty:
		return OK
	if terrain_store is BufferedWorldDeltaStore:
		var io: Dictionary = terrain_store.io_report()
		if io.dirty_chunks > 0 or io.writing:
			return ERR_BUSY
	var records: Array = []
	for tile: WaterTile in grid.tiles.values():
		if tile.revision > 0 or tile.activity == WaterTile.Activity.ACTIVE:
			records.append({"coord":[tile.coord.x,tile.coord.y],"depth":Marshalls.raw_to_base64(tile.depth.to_byte_array()),"kind":Marshalls.raw_to_base64(tile.kind)})
	var error := document.commit({"tiles":records,"external_volume":grid.external_volume})
	if error == OK:
		grid.dirty = false
	return error
func _exit_tree() -> void:
	flush()
