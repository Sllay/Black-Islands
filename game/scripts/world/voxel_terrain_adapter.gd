class_name VoxelTerrainAdapter
extends Node3D
## The only native terrain/query/edit boundary exposed to Black Island consumers.

signal region_changed(area: AABB)
var field := IslandField.new()
var native: VoxelLodTerrain
var generator: VoxelIslandGenerator
var edit_requests: int = 0

var deltas: WorldDeltaStore

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
	native.collision_update_delay = 16
	native.collision_layer = 1
	native.cache_generated_blocks = true
	var mesher := VoxelMesherTransvoxel.new()
	mesher.texturing_mode = VoxelMesherTransvoxel.TEXTURES_MIXEL4_S4
	mesher.textures_ignore_air_voxels = true
	native.mesher = mesher
	native.material = load("res://resources/world/TerrainMaterial.tres")
	generator = VoxelIslandGenerator.new()
	generator.field = field
	generator.deltas = deltas
	native.generator = generator

func is_editable(center: Vector3, radius: float) -> bool:
	if not is_finite(radius) or radius <= 0.0 or not center.is_finite():
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

func paint_sphere(center: Vector3, radius: float, logical_material: int) -> bool:
	if logical_material < 0 or logical_material > 3 or not is_editable(center, radius):
		return false
	var tool := native.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_SDF
	tool.mode = VoxelTool.MODE_TEXTURE_PAINT
	tool.texture_index = logical_material
	tool.texture_opacity = 1.0
	tool.texture_falloff = 0.5
	tool.do_sphere(native.to_local(center), radius / WorldCoordinates.VOXEL_SIZE)
	edit_requests += 1
	region_changed.emit(AABB(center - Vector3.ONE * radius, Vector3.ONE * radius * 2.0))
	return true

func material_at(world_point: Vector3) -> int:
	var tool := native.get_voxel_tool()
	var coord := Vector3i(native.to_local(world_point).floor())
	tool.channel = VoxelBuffer.CHANNEL_INDICES
	var indices := tool.get_voxel(coord)
	tool.channel = VoxelBuffer.CHANNEL_WEIGHTS
	var weights := tool.get_voxel(coord)
	var maximum := -1
	var selected := 0
	for index: int in range(4):
		var weight := (weights >> (index * 4)) & 15
		if weight > maximum:
			maximum = weight
			selected = (indices >> (index * 4)) & 15
	return selected

func surface_hit(x: float, z: float) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(Vector3(x, 100, z), Vector3(x, -120, z), 1)
	return get_world_3d().direct_space_state.intersect_ray(query)

func density_at(world_position: Vector3) -> float:
	var tool := native.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_SDF
	return tool.get_voxel_f(Vector3i(native.to_local(world_position).floor()))

func capture_samples(origin: Vector3i, extent: Vector3i) -> Dictionary:
	var buffer := VoxelBuffer.new()
	buffer.create(extent.x, extent.y, extent.z)
	native.get_voxel_tool().copy(origin, buffer, generator._get_used_channels_mask())
	var result: Dictionary = {}
	for z: int in range(extent.z):
		for x: int in range(extent.x):
			for y: int in range(extent.y):
				var indices := buffer.get_voxel(x, y, z, VoxelBuffer.CHANNEL_INDICES)
				var packed := buffer.get_voxel(x, y, z, VoxelBuffer.CHANNEL_WEIGHTS)
				var weights := [0, 0, 0, 0]
				for index: int in range(4):
					var logical := (indices >> (index * 4)) & 15
					if logical < 4:
						weights[logical] += (packed >> (index * 4)) & 15
				var code := buffer.get_voxel(x, y, z, VoxelBuffer.CHANNEL_SDF)
				if code >= 32768:
					code -= 65536
				result[origin + Vector3i(x, y, z)] = {"density": code, "materials": weights}
	return result

func restore_samples(origin: Vector3i, extent: Vector3i, samples: Dictionary) -> void:
	var buffer := VoxelBuffer.new()
	buffer.create(extent.x, extent.y, extent.z)
	buffer.fill(0x3210, VoxelBuffer.CHANNEL_INDICES)
	for voxel: Vector3i in samples:
		var cell := voxel - origin
		var sample: Dictionary = samples[voxel]
		buffer.set_voxel(int(sample.density) & 0xffff, cell.x, cell.y, cell.z, VoxelBuffer.CHANNEL_SDF)
		var weights := 0
		for index: int in range(4):
			weights |= int(sample.materials[index]) << (index * 4)
		buffer.set_voxel(weights, cell.x, cell.y, cell.z, VoxelBuffer.CHANNEL_WEIGHTS)
	native.get_voxel_tool().paste(origin, buffer, generator._get_used_channels_mask())

func collision_data_ready(world_point: Vector3) -> bool:
	var point := native.to_local(world_point)
	return native.is_area_meshed(AABB(point - Vector3(2,4,2), Vector3(4,8,4)), 0)

func statistics() -> Dictionary:
	return {"native": native.get_statistics(), "engine": Engine.get_singleton("VoxelEngine").call("get_stats"), "data_blocks": native.debug_get_data_block_count(), "mesh_blocks": native.debug_get_mesh_block_count(), "edit_requests": edit_requests}
