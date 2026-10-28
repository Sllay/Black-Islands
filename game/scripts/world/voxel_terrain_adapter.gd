class_name VoxelTerrainAdapter
extends Node3D
## The only native terrain/query/edit boundary exposed to Black Island consumers.

signal region_changed(area: AABB)
var field := IslandField.new()
var native: VoxelLodTerrain
var generator: VoxelIslandGenerator
var edit_requests: int = 0

func _ready() -> void:
	native = $Terrain
	native.scale = Vector3.ONE * WorldCoordinates.VOXEL_SIZE
	native.voxel_bounds = AABB(Vector3(-512, -256, -512), Vector3(1024, 512, 1024))
	native.mesh_block_size = 32
	native.lod_count = 4
	native.lod_distance = 64
	native.view_distance = 512
	native.streaming_system = VoxelLodTerrain.STREAMING_SYSTEM_CLIPBOX
	native.collision_lod_count = 1
	native.collision_update_delay = 0
	native.cache_generated_blocks = true
	native.mesher = VoxelMesherTransvoxel.new()
	native.material = load("res://resources/world/TerrainMaterial.tres")
	generator = VoxelIslandGenerator.new()
	generator.field = field
	native.generator = generator

func is_editable(center: Vector3, radius: float) -> bool:
	if radius <= 0.0 or not center.is_finite():
		return false
	var point := native.to_local(center)
	var extent := Vector3.ONE * (radius / WorldCoordinates.VOXEL_SIZE + 2.0)
	var area := AABB(point - extent, extent * 2.0)
	# v1.7x can accept edits while initial generation/meshing is still in flight,
	# leaving a stale first collider. Conservatively expose edits at an idle gate.
	# Data residency alone is not readiness. No global remesh is used as a repair.
	var tasks: Dictionary = Engine.get_singleton("VoxelEngine").call("get_stats").tasks
	return native.voxel_bounds.encloses(area) and native.get_voxel_tool().is_area_editable(area) and native.is_area_meshed(area, 0) and tasks.generation == 0 and tasks.meshing == 0 and tasks.main_thread == 0

func dig_sphere(center: Vector3, radius: float) -> bool:
	if not is_editable(center, radius):
		return false
	var tool := native.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_SDF
	tool.mode = VoxelTool.MODE_REMOVE
	tool.sdf_scale = 1.0
	tool.do_sphere(native.to_local(center), radius / WorldCoordinates.VOXEL_SIZE)
	edit_requests += 1
	region_changed.emit(AABB(center - Vector3.ONE * radius, Vector3.ONE * radius * 2.0))
	return true

func surface_hit(x: float, z: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, 100, z), Vector3(x, -120, z))
	return get_world_3d().direct_space_state.intersect_ray(query)

func density_at(world_position: Vector3) -> float:
	var tool := native.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_SDF
	return tool.get_voxel_f(Vector3i(native.to_local(world_position).floor()))

func statistics() -> Dictionary:
	return {"native": native.get_statistics(), "engine": Engine.get_singleton("VoxelEngine").call("get_stats"), "data_blocks": native.debug_get_data_block_count(), "mesh_blocks": native.debug_get_mesh_block_count(), "edit_requests": edit_requests}
