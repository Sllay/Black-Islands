class_name WorldWater
extends RefCounted
## Analytic ocean + generated sleeping lake. Interface seam for future WaterGrid;
## no dynamic flow solver, drainage or hydrology performance claim in P02.

var terrain: VoxelTerrainAdapter
var dirty_notifications := 0
var last_dirty_area := AABB()

func sample(point: Vector3) -> Dictionary:
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
