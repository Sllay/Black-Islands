class_name WorldWater
extends RefCounted
## Stable gameplay facade: dynamic inland water and cheap analytic ocean.

var motion_tuning: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/water/tuning.json"))
var domain: WaterDomain
var terrain: VoxelTerrainAdapter
var dirty_notifications := 0
var last_dirty_area := AABB()

func sample(point: Vector3) -> Dictionary:
	if domain != null:
		var dynamic := domain.grid.sample(point)
		if not dynamic.is_empty():
			return dynamic
	if terrain == null:
		return {"kind":"dry","level":0.0,"depth":0.0,"submerged":false,"current":Vector3.ZERO}
	var body := terrain.field.lake_body()
	var lake: bool = Vector2(point.x,point.z).distance_to(body.center) <= body.radius
	var water: Dictionary = terrain.field.water_at(Vector2(point.x,point.z)) if terrain.field is WorldFieldV2 else {"kind":"lake" if lake else "ocean","level":body.level if lake else 0.0}
	var level: float = water.level
	var top := terrain.field.top_surface(point.x, point.z)
	var hit := terrain.surface_hit(point.x, point.z)
	if not hit.is_empty():
		top = hit.position.y
	var depth := maxf(0, level - top) if is_finite(top) else 100.0
	return {"kind": water.kind if depth > 0.01 else "dry", "level": level,
		"depth": depth, "submerged": point.y < level and depth > 0.01, "current": Vector3.ZERO,
		"grid_cell": WorldCoordinates.world_to_cell(point)}

func invalidate_terrain(area: AABB) -> void:
	dirty_notifications += 1
	last_dirty_area = area
	if domain != null:
		domain.invalidate(area)
