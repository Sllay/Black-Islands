class_name VoxelTerrainAdapter
extends Node3D
## The only native terrain/query/edit boundary exposed to Black Island consumers.

signal region_changed(area: AABB)
var field := IslandField.new()
var native: VoxelLodTerrain
var generator: VoxelGeneratorGraph
var edit_requests: int = 0
var _recent_edits: Array[Dictionary] = []

var deltas: WorldDeltaStore

func _ready() -> void:
	native = $Terrain
	native.scale = Vector3.ONE*WorldCoordinates.VOXEL_SIZE
	native.voxel_bounds = AABB(Vector3(-2048,-512,-2048),Vector3(4096,1024,4096)) if field is WorldFieldV2 else AABB(Vector3(-512,-256,-512),Vector3(1024,512,1024))
	native.mesh_block_size = 32
	native.lod_count = 4
	native.lod_distance = 64
	native.view_distance = 512
	native.streaming_system = VoxelLodTerrain.STREAMING_SYSTEM_CLIPBOX
	native.collision_lod_count = 1
	native.collision_update_delay = 16
	native.collision_layer = CollisionLayers.WORLD
	native.cache_generated_blocks = false
	var mesher := VoxelMesherTransvoxel.new()
	mesher.texturing_mode = VoxelMesherTransvoxel.TEXTURES_MIXEL4_S4
	mesher.textures_ignore_air_voxels = true
	native.mesher = mesher
	native.material = load("res://resources/world/TerrainMaterial.tres")
	if field is WorldFieldV2:
		generator = field.graph
	else:
		var builder := NativeTerrainGraph.new()
		var result := builder.build_legacy(field)
		assert(result.success,str(result))
		generator = builder.generator
	var stream := VoxelDeltaStream.new()
	stream.base = generator
	stream.deltas = deltas
	native.stream = stream
	native.generator = generator

func is_editable(center: Vector3, radius: float) -> bool:
	if native == null or not center.is_finite() or not is_finite(radius) or radius <= 0:
		return false
	if field is WorldFieldV2:
		var water: Dictionary = field.water_at(Vector2(center.x,center.z))
		if water.kind == "ocean" and field.top_surface(center.x,center.z) < -float(field.profile.elevation_step)*3:
			return false
	var world_area := AABB(center-Vector3.ONE*radius,Vector3.ONE*radius*2)
	var now := Time.get_ticks_msec()
	for index: int in range(_recent_edits.size()-1,-1,-1):
		if now >= int(_recent_edits[index].until):
			_recent_edits.remove_at(index)
		elif world_area.intersects(_recent_edits[index].area):
			return false
	var point := native.to_local(center)
	var extent := Vector3.ONE*(radius/WorldCoordinates.VOXEL_SIZE+2)
	var area := AABB(point-extent,extent*2)
	if not native.voxel_bounds.encloses(area) or not native.get_voxel_tool().is_area_editable(area) or not native.is_area_meshed(area,0):
		return false
	var first := Vector3i((area.position/float(native.mesh_block_size)).floor())
	var last := Vector3i((area.end/float(native.mesh_block_size)).floor())
	for z: int in range(first.z,last.z+1):
		for x: int in range(first.x,last.x+1):
			for y: int in range(first.y,last.y+1):
				var block := native.debug_get_mesh_block_info(Vector3i(x,y,z),0)
				if block.get("meshed",false) and not block.get("collision_active",false):
					return false
	return true

func dig_sphere(center: Vector3, radius: float) -> bool:
	if not is_editable(center, radius):
		return false
	var tool := native.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_SDF
	tool.mode = VoxelTool.MODE_REMOVE
	tool.sdf_scale = 1.0
	tool.do_sphere(native.to_local(center), radius / WorldCoordinates.VOXEL_SIZE)
	edit_requests += 1
	_recent_edits.append({"area":AABB(center-Vector3.ONE*radius,Vector3.ONE*radius*2),"until":Time.get_ticks_msec()+50})
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
	_recent_edits.append({"area":AABB(center-Vector3.ONE*radius,Vector3.ONE*radius*2),"until":Time.get_ticks_msec()+50})
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
	# Frontend navigation can detach a world before queued presenters finish.
	if not is_inside_tree():
		return {}
	var query := PhysicsRayQueryParameters3D.create(Vector3(x,100,z),Vector3(x,-120,z),CollisionLayers.WORLD)
	return get_world_3d().direct_space_state.intersect_ray(query)

func density_at(world_position: Vector3) -> float:
	var tool := native.get_voxel_tool()
	tool.channel = VoxelBuffer.CHANNEL_SDF
	return tool.get_voxel_f(Vector3i(native.to_local(world_position).floor()))

func capture_samples(origin: Vector3i, extent: Vector3i) -> Dictionary:
	var buffer := VoxelBuffer.new()
	buffer.create(extent.x, extent.y, extent.z)
	native.get_voxel_tool().copy(origin, buffer, NativeTerrainGraph.CHANNELS)
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
	native.get_voxel_tool().paste(origin, buffer, NativeTerrainGraph.CHANNELS)

func collision_data_ready(world_point: Vector3) -> bool:
	var point := native.to_local(world_point)
	return native.is_area_meshed(AABB(point - Vector3(2,4,2), Vector3(4,8,4)), 0)

func statistics() -> Dictionary:
	return {"native": native.get_statistics(), "engine": Engine.get_singleton("VoxelEngine").call("get_stats"), "data_blocks": native.debug_get_data_block_count(), "mesh_blocks": native.debug_get_mesh_block_count(), "edit_requests": edit_requests}

func capture_buffer(origin: Vector3i, extent: Vector3i, buffer: VoxelBuffer) -> void:
	if buffer.get_size() != extent:
		buffer.create(extent.x,extent.y,extent.z)
	native.get_voxel_tool().copy(origin,buffer,NativeTerrainGraph.CHANNELS)

func difference(before: VoxelBuffer, after: VoxelBuffer, origin: Vector3i) -> Dictionary:
	var a_sdf := before.get_channel_as_byte_array(VoxelBuffer.CHANNEL_SDF)
	var a_indices := before.get_channel_as_byte_array(VoxelBuffer.CHANNEL_INDICES)
	var a_weights := before.get_channel_as_byte_array(VoxelBuffer.CHANNEL_WEIGHTS)
	var b_sdf := after.get_channel_as_byte_array(VoxelBuffer.CHANNEL_SDF)
	var b_indices := after.get_channel_as_byte_array(VoxelBuffer.CHANNEL_INDICES)
	var b_weights := after.get_channel_as_byte_array(VoxelBuffer.CHANNEL_WEIGHTS)
	var changes: Dictionary = {}
	var size := after.get_size()
	for index: int in size.x*size.y*size.z:
		var offset := index*2
		if a_sdf.decode_u16(offset) == b_sdf.decode_u16(offset) and a_indices.decode_u16(offset) == b_indices.decode_u16(offset) and a_weights.decode_u16(offset) == b_weights.decode_u16(offset):
			continue
		@warning_ignore("integer_division")
		var cell := Vector3i((index/size.y)%size.x,index%size.y,index/(size.y*size.x))
		var indices := b_indices.decode_u16(offset)
		var packed := b_weights.decode_u16(offset)
		var weights := [0,0,0,0]
		for material: int in 4:
			var logical := (indices>>(material*4))&15
			if logical < 4:
				weights[logical] += (packed>>(material*4))&15
		changes[origin+cell] = {"density":b_sdf.decode_s16(offset),"materials":weights}
	return changes
