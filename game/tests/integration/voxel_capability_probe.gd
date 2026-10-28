extends SceneTree
## S01-P00 dependency probe only: no island, gameplay state or scene assets.
## Run: .tools/bin/godot --headless --path game --script res://tests/integration/voxel_capability_probe.gd

const REQUIRED_CLASSES: Array[StringName] = [
	&"VoxelBuffer", &"VoxelMesherTransvoxel", &"VoxelLodTerrain",
	&"VoxelGeneratorNoise", &"VoxelViewer", &"VoxelToolLodTerrain", &"VoxelStreamRegionFiles",
]
const BLOCK_SIZE: int = 16


func _initialize() -> void:
	for class_name_to_check: StringName in REQUIRED_CLASSES:
		if not ClassDB.class_exists(class_name_to_check):
			_fail("Required extension class unavailable: %s" % class_name_to_check)
			return
	if not ClassDB.class_has_method(&"VoxelToolLodTerrain", &"is_area_editable"):
		_fail("Terrain editability guard unavailable")
		return
	_probe_smooth_path()


func _probe_smooth_path() -> void:
	var mesher := VoxelMesherTransvoxel.new()
	var padding: int = mesher.get_minimum_padding() + mesher.get_maximum_padding()
	var size: int = BLOCK_SIZE + padding
	var buffer := VoxelBuffer.new()
	buffer.set_channel_depth(VoxelBuffer.CHANNEL_SDF, VoxelBuffer.DEPTH_32_BIT)
	buffer.create(size, size, size)
	var center := Vector3.ONE * (float(size - 1) * 0.5)
	for z: int in range(size):
		for x: int in range(size):
			for y: int in range(size):
				var distance: float = Vector3(x, y, z).distance_to(center) - 5.5
				buffer.set_voxel_f(distance, x, y, z, VoxelBuffer.CHANNEL_SDF)
	if buffer.get_voxel_f(size >> 1, size >> 1, size >> 1, VoxelBuffer.CHANNEL_SDF) >= 0.0:
		_fail("Sphere center did not preserve negative SDF")
		return
	if buffer.get_voxel_f(0, 0, 0, VoxelBuffer.CHANNEL_SDF) <= 0.0:
		_fail("Sphere exterior did not preserve positive SDF")
		return
	var mesh: Mesh = mesher.build_mesh(buffer, [])
	if mesh == null or mesh.get_surface_count() == 0:
		_fail("Transvoxel did not produce a sphere surface")
		return
	var vertices: PackedVector3Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX]
	if vertices.is_empty() or indices.size() < 3:
		_fail("Sphere surface has no triangle geometry")
		return
	var terrain := VoxelLodTerrain.new()
	terrain.mesher = mesher
	terrain.lod_count = 4
	var terrain_ready: bool = terrain.mesher == mesher and terrain.lod_count == 4
	terrain.free()
	if not terrain_ready:
		_fail("Smooth terrain/mesher LOD configuration did not round-trip")
		return
	var helper_requested: bool = OS.get_cmdline_user_args().has("--transition-helper")
	if helper_requested and not _probe_transition_helper(mesher, buffer, size, center):
		_fail("Standalone Transvoxel transition helper produced no surfaces; see research/VOXEL_TOOLS_INTEGRATION.md")
		return
	print(JSON.stringify({
		"result": "PASS", "probe": "voxel_capability", "classes": REQUIRED_CLASSES,
		"sphere_vertices": vertices.size(), "sphere_indices": indices.size(),
		"lod_count": 4, "transition_helper": "PASS" if helper_requested else "not_requested",
		"scope": "desktop_headless_capability_only",
	}))
	quit(0)


func _probe_transition_helper(mesher: VoxelMesherTransvoxel, buffer: VoxelBuffer, size: int, center: Vector3) -> bool:
	# Optional regression reproduction, not a claim about rendered terrain LOD seams.
	# A plane crossing the padded block's side faces should yield transition geometry.
	for z: int in range(size):
		for x: int in range(size):
			for y: int in range(size):
				buffer.set_voxel_f(float(y) - center.y - 0.25, x, y, z, VoxelBuffer.CHANNEL_SDF)
	var transition_surfaces: int = 0
	for direction: int in range(6):
		var transition: ArrayMesh = mesher.build_transition_mesh(buffer, direction)
		if transition != null:
			transition_surfaces += transition.get_surface_count()
	return transition_surfaces > 0


func _fail(reason: String) -> void:
	push_error("Voxel capability probe: %s" % reason)
	quit(1)
