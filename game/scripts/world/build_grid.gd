class_name BuildGrid
extends RefCounted
## 1m occupancy and shared wall-edge identity. No structure catalog/support solver.

const HEIGHT_LIMIT := 100
var _occupied: Dictionary = {}

func reserve(cell: Vector3i, owner_id: String) -> Error:
	if cell.y > HEIGHT_LIMIT or owner_id.is_empty():
		return ERR_INVALID_PARAMETER
	if _occupied.has(cell):
		return ERR_ALREADY_IN_USE
	_occupied[cell] = owner_id
	return OK

func release(cell: Vector3i, owner_id: String) -> Error:
	if _occupied.get(cell) != owner_id:
		return ERR_UNAUTHORIZED
	_occupied.erase(cell)
	return OK

func occupant(cell: Vector3i) -> String:
	return _occupied.get(cell, "")

static func shared_edge(a: Vector3i, b: Vector3i) -> String:
	var delta := (a - b).abs()
	if a.y != b.y or delta.x + delta.z != 1:
		return ""
	return "%d,%d,%d/%s" % [mini(a.x, b.x), a.y, mini(a.z, b.z), "x" if delta.x == 1 else "z"]
