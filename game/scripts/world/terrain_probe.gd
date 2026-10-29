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

var last_seam_report: Dictionary = {}

func prepare_seam_view(point: Vector3 = Vector3.ZERO) -> void:
	$Viewer.position = point + Vector3(0, 16, 0)
	$Camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	$Camera.size = 150
	$Camera.position = point + Vector3(0, 200, 0)
	$Camera.look_at(point, Vector3.FORWARD)

func capture_seam_report() -> void:
	await RenderingServer.frame_post_draw
	var picture := get_viewport().get_texture().get_image()
	var holes := 0
	for y: int in range(16, picture.get_height() - 16):
		for x: int in range(16, picture.get_width() - 16):
			var color := picture.get_pixel(x, y)
			if color.r > 0.85 and color.b > 0.85 and color.g < 0.15:
				holes += 1
	var lods: Dictionary = {}
	var transitions := 0
	for lod: int in range(4):
		var span := 16.0 * (1 << lod)
		var blocks := int(150.0 / span) + 2
		var center := Vector3i(($Viewer.position / span).floor())
		var visible_blocks := 0
		for z: int in range(center.z - blocks, center.z + blocks + 1):
			for x: int in range(center.x - blocks, center.x + blocks + 1):
				for y: int in range(-1, 2):
					var info := terrain.native.debug_get_mesh_block_info(Vector3(x,y,z), lod)
					if info.get("visible", false) and info.get("meshed", false):
						visible_blocks += 1
						if info.get("transition_mask", 0) != 0:
							transitions += 1
		lods[lod] = visible_blocks
	last_seam_report = {"background_holes": holes, "visible_lods": lods, "transition_blocks": transitions,
		"viewport": picture.get_size(), "viewer": $Viewer.position, "native_jobs": terrain.statistics().engine.tasks}
	print("RENDERED_SEAM ", last_seam_report)
