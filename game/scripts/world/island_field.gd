class_name IslandField
extends RefCounted
## Immutable generation inputs once handed to native worker jobs.

const VERSION := 1
const PROFILE_ID := "chapter1_iteration_480m_v1"
var world_seed: int
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
	return lerpf(hills, 12.0, clearing)

func density(position: Vector3) -> float:
	var q := Vector3(position.x / radius.x, (position.y + 35.0) / 65.0, position.z / radius.y)
	var body := (q.length() - 1.0) * 50.0
	return maxf(body, position.y - surface_height(position.x, position.z))

func material_at(position: Vector3) -> int:
	if position.y < 3.0:
		return 0 # sand
	if position.y > 23.0:
		return 3 # stone
	return 1 # grass; soil is also available to paint

func forest_weight(position: Vector3) -> float:
	return clampf(1.0 - Vector2(position.x, position.z).length() / 150.0, 0.0, 1.0)
