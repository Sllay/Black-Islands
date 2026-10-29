class_name SupportGraph
extends RefCounted
## Indexed topology + independent root candidates. Materials never change reach.
var pieces: Dictionary = {}
var occupancy: Dictionary = {}
var candidates: Dictionary = {}
var _index: Dictionary = {}
var ground: Callable
var last_benchmark := {"examined":0,"invalidated":0,"microseconds":0}
var removed_on_restore: Array[Dictionary] = []

static func cell(row: Dictionary) -> Vector3i:
	return Vector3i(int(row.cell[0]),int(row.cell[1]),int(row.cell[2]))

static func slot(definition: String, position: Vector3i, rotation: int = 0) -> String:
	position = StructureModule.snap(position)
	if definition == "wall":
		var side := posmod(rotation,4)
		var edge := position
		if side == 0:
			edge.x += StructureModule.SIZE
		elif side == 1:
			edge.z += StructureModule.SIZE
		return "E:%d,%d,%d/%s" % [edge.x,edge.y,edge.z,"x" if side%2 == 0 else "z"]
	return ("P:" if definition == "pillar" else "C:")+str(position)

func place(id: String, definition: String, position: Vector3i, rotation: int = 0, tier: String = "wood") -> Error:
	position = StructureModule.snap(position)
	if id.is_empty() or pieces.has(id) or definition not in SurfaceCatalog.data().structures or tier not in SurfaceCatalog.data().tiers or position.y+2 > BuildGrid.HEIGHT_LIMIT:
		return ERR_INVALID_PARAMETER
	var key := slot(definition,position,rotation)
	if occupancy.has(key):
		return ERR_ALREADY_IN_USE
	if definition == "wall":
		if posmod(rotation,4) == 2:
			position += Vector3i.LEFT*StructureModule.SIZE
		elif posmod(rotation,4) == 3:
			position += Vector3i.FORWARD*StructureModule.SIZE
		rotation = posmod(rotation,2)
	var hp := float(SurfaceCatalog.data().tiers[tier].hp)
	var row := {"id":id,"definition":definition,"cell":[position.x,position.y,position.z],"rotation":rotation,
		"tier":tier,"health":hp,"owner_scope":"PLAYER","occupancy":key}
	_insert(row)
	var affected := component([id])
	_solve(affected)
	if candidates.get(id,{}).is_empty():
		_erase(id)
		_solve(affected)
		return ERR_UNAVAILABLE
	return OK

func _insert(row: Dictionary) -> void:
	pieces[row.id] = row
	occupancy[row.occupancy] = row.id
	var point := cell(row)
	if not _index.has(point):
		_index[point] = []
	_index[point].append(row.id)

func _erase(id: String) -> void:
	if not pieces.has(id):
		return
	var row: Dictionary = pieces[id]
	occupancy.erase(row.occupancy)
	_index[cell(row)].erase(id)
	if _index[cell(row)].is_empty():
		_index.erase(cell(row))
	pieces.erase(id)
	candidates.erase(id)

func adjacent(id: String) -> Array[String]:
	var result: Array[String] = []
	if not pieces.has(id):
		return result
	var row: Dictionary = pieces[id]
	var point := cell(row)
	for y: int in [-2,0,2]:
		for z: int in [-2,0,2]:
			for x: int in [-2,0,2]:
				for other: String in _index.get(point+Vector3i(x,y,z),[]):
					if other == id:
						continue
					if _socket_link(row,pieces[other]):
						result.append(other)
	return result

func _socket_link(a: Dictionary, b: Dictionary) -> bool:
	var delta := cell(b)-cell(a)
	var a_floor: bool = a.definition in ["foundation","ceiling"]
	var b_floor: bool = b.definition in ["foundation","ceiling"]
	if a_floor and b_floor:
		return delta.y == 0 and maxi(absi(delta.x),absi(delta.z)) == StructureModule.SIZE
	if a.definition == "pillar" or b.definition == "pillar":
		return delta.x == 0 and delta.z == 0 and absi(delta.y) <= 2
	if a.definition == "wall" and b.definition == "wall":
		return delta.x == 0 and delta.z == 0 and absi(delta.y) == 2 and a.rotation == b.rotation
	var wall := a if a.definition == "wall" else b
	var floor_row := b if a.definition == "wall" else a
	var wall_cell := cell(wall)
	var side := (Vector3i.RIGHT if int(wall.rotation)%2 == 0 else Vector3i.BACK)*StructureModule.SIZE
	return cell(floor_row) in [wall_cell,wall_cell+side,wall_cell+Vector3i.UP*2,wall_cell+side+Vector3i.UP*2]

func component(seeds: Array) -> Dictionary:
	var found: Dictionary = {}
	var queue := seeds.duplicate()
	while not queue.is_empty():
		var id: String = queue.pop_back()
		if found.has(id) or not pieces.has(id):
			continue
		found[id] = true
		queue.append_array(adjacent(id))
	return found

var foundation_ground: Callable

func _root_supported(row: Dictionary) -> bool:
	if row.definition == "foundation" and foundation_ground.is_valid():
		return foundation_ground.call(cell(row))
	return ground.call(cell(row))

func _solve(affected: Dictionary) -> void:
	var started := Time.get_ticks_usec()
	for id: String in affected:
		if pieces.has(id):
			candidates[id] = {}
	var roots: Dictionary = {}
	for id: String in affected:
		if pieces.has(id) and pieces[id].definition in ["foundation","pillar"] and _root_supported(pieces[id]):
			roots[id] = true
	for root: String in roots:
		var origin := cell(pieces[root])
		var queue: Array = [[root,root]]
		var visited: Dictionary = {}
		while not queue.is_empty():
			var entry: Array = queue.pop_back()
			var id: String = entry[0]
			if visited.has(id) or not affected.has(id) or not pieces.has(id):
				continue
			visited[id] = true
			# A foundation is ground-bearing, not a cantilever deck in disguise.
			if pieces[id].definition == "foundation" and not roots.has(id):
				continue
			var delta := cell(pieces[id])-origin
			var distance := float(maxi(absi(delta.x),absi(delta.z)))/StructureModule.SIZE
			if distance > 2:
				continue
			candidates[id][root] = {"root_xz":[origin.x,origin.z],"distance":distance,"via":entry[1]}
			for next: String in adjacent(id):
				queue.append([next,id])
	last_benchmark = {"examined":affected.size(),"invalidated":0,"microseconds":Time.get_ticks_usec()-started}

func remove(id: String) -> Array[Dictionary]:
	var affected := component([id])
	var removed: Array[Dictionary] = []
	if pieces.has(id):
		removed.append(pieces[id].duplicate(true))
	_erase(id)
	_solve(affected)
	for key: String in affected:
		if pieces.has(key) and candidates.get(key,{}).is_empty():
			removed.append(pieces[key].duplicate(true))
			_erase(key)
	last_benchmark.invalidated = removed.size()
	return removed

func restore(rows: Dictionary) -> Error:
	for id: String in rows:
		var row: Dictionary = rows[id]
		if row.get("id") != id or not row.get("cell") is Array or row.cell.size() != 3 or row.get("definition") not in SurfaceCatalog.data().structures:
			return ERR_INVALID_DATA
		var expected := slot(row.definition,cell(row),int(row.rotation))
		if occupancy.has(expected) or expected != row.get("occupancy"):
			return ERR_INVALID_DATA
		_insert(row.duplicate(true))
	_solve(pieces.duplicate())
	for id: String in pieces.keys():
		if candidates.get(id,{}).is_empty():
			removed_on_restore.append(pieces[id].duplicate(true))
			_erase(id)
	return OK

func terrain_changed(area: AABB) -> Array[Dictionary]:
	var seeds: Array = []
	var start := Vector3i(area.position.floor())-Vector3i(2,1,2)
	var end := Vector3i(area.end.ceil())+Vector3i.ONE
	for y: int in range(start.y,end.y+1):
		for z: int in range(start.z,end.z+1):
			for x: int in range(start.x,end.x+1):
				seeds.append_array(_index.get(Vector3i(x,y,z),[]))
	var affected := component(seeds)
	_solve(affected)
	var removed: Array[Dictionary] = []
	for id: String in affected:
		if candidates.get(id,{}).is_empty():
			removed.append(pieces[id].duplicate(true))
			_erase(id)
	last_benchmark.invalidated = removed.size()
	return removed
