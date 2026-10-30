class_name NativeFoliage
extends Node
## Native block-scoped disposable instances; ledger owns sparse suppression.
var runtime: SurfaceRuntime
var instancer: VoxelInstancer
var material: ShaderMaterial
var decoration_materials: Array[ShaderMaterial] = []
var mask: Image
var mask_texture: ImageTexture
var mask_origin := Vector2(INF,INF)
var mask_dirty := true
var enabled := true
var budget: Dictionary = {"density":.25,"near":22.0,"far":36.0,"interaction":2.0,"wind":.12}
var _poll := 0.0
func _ready() -> void:
	mask = Image.create(128,128,false,Image.FORMAT_R8)
	mask_texture = ImageTexture.create_from_image(mask)
	runtime.ledger.changed.connect(func(_domain: String,_id: String) -> void: mask_dirty = true)
	_rebuild()
func _rebuild() -> void:
	# Keep old materials alive until native clear_layers detaches their RIDs.
	var previous_library: VoxelInstanceLibrary = instancer.library if is_instance_valid(instancer) else null
	var library := VoxelInstanceLibrary.new()
	decoration_materials.clear()
	material = ShaderMaterial.new()
	var shader: Shader = load("res://resources/surface/grass.gdshader")
	var rd := RenderingServer.get_current_rendering_method() != "gl_compatibility"
	if rd:
		shader = shader.duplicate()
		shader.code = shader.code.replace("uniform vec2 u_lod_fade = vec2(1.0);","instance uniform vec2 u_lod_fade = vec2(1.0);")
	material.shader = shader
	material.set_shader_parameter("blades",GrassGeometry.blade_texture())
	material.set_shader_parameter("suppression",mask_texture)
	for pair: Array in [["near_distance","near"],["far_distance","far"],["interaction_radius","interaction"],["wind_amplitude","wind"]]:
		material.set_shader_parameter(pair[0],budget[pair[1]])
	var item := VoxelInstanceLibraryMultiMeshItem.new()
	item.name = "grass_cluster_v1"
	item.lod_index = 0
	item.mesh = GrassGeometry.cluster(3)
	item.mesh_lod1 = GrassGeometry.cluster(2)
	item.mesh_lod2 = GrassGeometry.cluster(1)
	item.mesh_lod0_distance_ratio = .3
	item.mesh_lod1_distance_ratio = .6
	item.mesh_lod2_distance_ratio = 1
	item.material_override = material
	item.cast_shadow = RenderingServer.SHADOW_CASTING_SETTING_OFF
	item.persistent = false # Suppression state, not transforms, is persisted.
	var generator := VoxelInstanceGenerator.new()
	generator.emit_mode = VoxelInstanceGenerator.EMIT_FROM_FACES
	generator.density = float(budget.density) if enabled else 0.0
	generator.max_slope_degrees = 38
	generator.max_slope_falloff_degrees = 6
	generator.min_height = 4.0
	generator.min_height_falloff = 2.0
	generator.min_scale = .75
	generator.max_scale = 1.15
	generator.voxel_texture_filter_enabled = true
	generator.voxel_texture_filter_array = PackedInt32Array([1])
	generator.voxel_texture_filter_threshold = .55
	generator.snap_to_generator_sdf_enabled = true
	generator.snap_to_generator_sdf_search_distance = 4
	generator.snap_to_generator_sdf_sample_count = 2
	var noise := FastNoiseLite.new()
	noise.seed = runtime.terrain.field.world_seed
	noise.frequency = .035
	generator.noise = noise
	generator.noise_dimension = VoxelInstanceGenerator.DIMENSION_2D
	generator.noise_threshold = .8
	generator.noise_falloff = .1
	item.generator = generator
	library.add_item(1,item)
	# Decorative rocks/bushes use native distribution, no script/collider each.
	for row: Array in [[2,"bush",.0015,1],[3,"pebble",.001,1]]:
		var decoration := VoxelInstanceLibraryMultiMeshItem.new()
		decoration.name = row[1]
		decoration.lod_index = int(row[3])
		decoration.mesh = load("res://resources/surface/"+str(row[1])+".res")
		var decoration_material := ShaderMaterial.new()
		decoration_material.shader = load("res://resources/surface/decorative_foliage.gdshader")
		decoration_material.set_shader_parameter("suppression",mask_texture)
		decoration_material.set_shader_parameter("far_distance",float(budget.far)+24)
		decoration_material.set_shader_parameter("tint",Vector3(.25,.48,.2) if row[1] == "bush" else Vector3(.48,.5,.54))
		decoration.material_override = decoration_material
		decoration_materials.append(decoration_material)
		var placement := VoxelInstanceGenerator.new()
		placement.emit_mode = VoxelInstanceGenerator.EMIT_FROM_FACES
		placement.density = float(row[2]) if enabled else 0.0
		placement.max_slope_degrees = 35
		placement.min_height = 5
		placement.min_scale = 1.6
		placement.max_scale = 2.2
		placement.snap_to_generator_sdf_enabled = true
		decoration.generator = placement
		decoration.cast_shadow = RenderingServer.SHADOW_CASTING_SETTING_OFF
		library.add_item(row[0],decoration)
	if not is_instance_valid(instancer):
		instancer = VoxelInstancer.new()
		instancer.name = "NativeFoliage"
		instancer.library = library
		runtime.terrain.native.add_child(instancer)
	else:
		# Native set_library regenerates layers against already-resident meshes.
		# Replacing the Node loses those mesh events until streaming moves again.
		instancer.library = library
	instancer.fading_enabled = rd
	instancer.fading_duration = .45
	if previous_library != null:
		previous_library = null
	mask_dirty = true
func apply_budget(values: Dictionary, active: bool = true) -> void:
	if budget == values and enabled == active:
		return
	budget = values.duplicate()
	enabled = active
	if is_inside_tree():
		_rebuild()
func _process(delta: float) -> void:
	if material == null or not runtime.player.spawned:
		return
	_poll += delta
	if _poll < .1:
		return
	_poll = 0
	var player := runtime.player.global_position
	material.set_shader_parameter("viewer",player)
	for decoration: ShaderMaterial in decoration_materials:
		decoration.set_shader_parameter("viewer",player)
	var positions := PackedVector4Array([Vector4(player.x,player.y,player.z,1)])
	if runtime.mobs != null:
		for actor: Node3D in runtime.mobs.actors.values():
			if positions.size() >= 5:
				break
			var point := actor.global_position
			positions.append(Vector4(point.x,point.y,point.z,1))
	while positions.size() < 5:
		positions.append(Vector4.ZERO)
	material.set_shader_parameter("actors",positions)
	var origin := Vector2(floorf(player.x/32)*32-64,floorf(player.z/32)*32-64)
	if origin != mask_origin:
		mask_origin = origin
		mask_dirty = true
	if mask_dirty:
		_update_mask()
func _update_mask() -> void:
	mask.fill(Color.BLACK)
	for key: String in runtime.ledger.suppression:
		var parts := key.split(",")
		var point := Vector3(float(parts[0]),float(parts[1]),float(parts[2]))
		if runtime.ledger.suppressed(point):
			var pixel := Vector2i(Vector2(point.x,point.z)-mask_origin)
			if pixel.x >= 0 and pixel.y >= 0 and pixel.x < 128 and pixel.y < 128:
				mask.set_pixel(pixel.x,pixel.y,Color.WHITE)
	mask_texture.update(mask)
	material.set_shader_parameter("mask_origin",mask_origin)
	for decoration: ShaderMaterial in decoration_materials:
		decoration.set_shader_parameter("mask_origin",mask_origin)
	mask_dirty = false
func remove_local(point: Vector3, radius: float) -> void:
	instancer.remove_instances_in_sphere(instancer.to_local(point),radius/WorldCoordinates.VOXEL_SIZE)
	mask_dirty = true
func report() -> Dictionary:
	var counts := instancer.debug_get_instance_counts()
	return {"native_instances":counts,"native_blocks":instancer.debug_get_block_count(),"density":budget.density,
		"distance":budget.far,"native_fading":instancer.fading_enabled,"mask_bytes":128*128,"mesh_lods":[3,2,1]}
func _exit_tree() -> void:
	if is_instance_valid(instancer):
		instancer.queue_free()
