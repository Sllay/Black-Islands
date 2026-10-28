extends Node3D
## Permanent dependency QA entrypoint, using the real native terrain path.

var terrain: VoxelTerrainAdapter
var ready_ms: int = -1
var started: int

func _ready() -> void:
	started = Time.get_ticks_msec()
	terrain = $WorldTerrain
	$Camera.look_at(Vector3(0, 12, 0))

func _process(_delta: float) -> void:
	if ready_ms < 0 and terrain.is_editable(Vector3(0, 12, 0), 2) and not terrain.surface_hit(0,0).is_empty():
		ready_ms = Time.get_ticks_msec() - started
		print("NATIVE_TERRAIN_READY ", ready_ms, "ms ", terrain.statistics())
