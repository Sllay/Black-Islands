class_name IslandField
extends RefCounted
## Immutable generation inputs once handed to native worker jobs.

const VERSION := 1
const PROFILE_ID := "chapter1_iteration_480m_v1"
var world_seed: int
var generation_version := VERSION
var profile_id := PROFILE_ID
var radius := Vector2(240.0, 210.0)
var noise := FastNoiseLite.new()

func _init(seed_value: int = 424242) -> void:
	world_seed = seed_value
	noise.seed = seed_value
	noise.frequency = 0.012
	noise.fractal_octaves = 3

func surface_height(x: float, z: float) -> float:
	var hills := 14.0 + 16.0 * noise.get_noise_2d(x, z)
	var clearing := 1.0 - smoothstep(16.0, 42.0, Vector2(x, z).length())
	var height := lerpf(hills, 12.0, clearing)
	var lake_distance := Vector2(x + 72.0, z - 48.0).length()
	var basin := 4.0 + 5.0 * pow(lake_distance / 18.0, 2.0)
	return lerpf(minf(height, basin), height, smoothstep(18.0, 28.0, lake_distance))

func density(position: Vector3) -> float:
	var q := Vector3(position.x / radius.x, (position.y + 35.0) / 65.0, position.z / radius.y)
	var body := (q.length() - 1.0) * 50.0
	return maxf(body, position.y - surface_height(position.x, position.z))

func material_at(world_point: Vector3) -> int:
	var top := top_surface(world_point.x, world_point.z)
	return material_for(world_point.y, top) if is_finite(top) else 3

func forest_weight(world_point: Vector3) -> float:
	var distance := Vector2(world_point.x, world_point.z).length()
	return clampf(1.0 - distance / 170.0, 0.0, 1.0) * smoothstep(28.0, 55.0, distance)

func material_for(y: float, top: float) -> int:
	# Surface ownership survives the 4m coarsest sample spacing. A thin grass
	# layer would become dirt at lower LODs and expose rectangular LOD bands.
	if y < top - 12.0 or y > 23.0:
		return 3
	if y < 3.5 and y >= top - 8.0:
		return 0
	if y < top - 8.0:
		return 2
	return 1

func top_surface(x: float, z: float) -> float:
	var radial := x * x / (radius.x * radius.x) + z * z / (radius.y * radius.y)
	if radial > 1.0:
		return -INF
	return minf(surface_height(x, z), -35.0 + 65.0 * sqrt(1.0 - radial))

func lake_body() -> Dictionary:
	return {"id": "lake_01", "center": Vector2(-72, 48), "radius": 15.0, "level": 8.0}
