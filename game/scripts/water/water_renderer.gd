class_name WaterRenderer
extends Node3D
## Static grouped geometry, small per-tile state textures. No cell Nodes.
var domain: WaterDomain
var views: Dictionary = {}
var material: ShaderMaterial
var quality := "Medium"
var rebuild_ms := 0.0
var worst_mesh_ms := 0.0
var ripple_cap := 2
var emitters: Array[Vector4] = []
var falls: MeshInstance3D
var _fall_tick := 0.0
func _ready() -> void:
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/water_surface.gdshader")
	apply_profile(GameSettings.effective())
	falls = MeshInstance3D.new()
	falls.name = "WaterfallConnections"
	falls.material_override = material
	falls.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(falls)
func apply_profile(profile: Dictionary) -> void:
	quality = str(profile.quality)
	var visual: Dictionary = profile.get("water",{"wave":.04,"foam":.4,"ripples":2})
	ripple_cap = clampi(int(visual.ripples),0,4)
	var materials: Array[ShaderMaterial] = [material,load("res://resources/world/OceanMaterial.tres")]
	for view: Dictionary in views.values():
		materials.append(view.material)
	for target: ShaderMaterial in materials:
		if target != null:
			target.set_shader_parameter("wave_amplitude",float(visual.wave))
			target.set_shader_parameter("foam_strength",float(visual.foam))
func _process(delta: float) -> void:
	if domain == null or material == null:
		return
	var interactions := PackedVector4Array()
	for emitter: Vector4 in emitters.slice(0,ripple_cap):
		interactions.append(emitter)
	if domain.observer != null and interactions.size() < ripple_cap:
		var point := domain.observer.global_position
		if domain.grid.sample(point).get("depth",0) > .1:
			interactions.append(Vector4(point.x,point.y,point.z,1))
	while interactions.size() < 4:
		interactions.append(Vector4.ZERO)
	var blend := clampf(domain.accumulator*domain.grid.tuning.solver_hz,0,1)
	material.set_shader_parameter("emitters",interactions)
	material.set_shader_parameter("blend",blend)
	_fall_tick += delta
	if _fall_tick >= .1:
		_fall_tick = 0
		_waterfalls()
	var started := Time.get_ticks_usec()
	for key: Vector2i in domain.grid.tiles:
		var tile: WaterTile = domain.grid.tiles[key]
		if tile.activity == WaterTile.Activity.INACTIVE:
			if views.has(key):
				views[key].view.visible = false
			continue
		if not views.has(key):
			var view := MeshInstance3D.new()
			var tile_material: ShaderMaterial = material.duplicate()
			tile_material.set_shader_parameter("grid_surface",true)
			tile_material.set_shader_parameter("tile_side",float(tile.side))
			view.material_override = tile_material
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			view.mesh = _mesh(tile)
			view.custom_aabb = AABB(Vector3(key.x*domain.grid.tuning.tile_metres,-160,key.y*domain.grid.tuning.tile_metres),Vector3(domain.grid.tuning.tile_metres,320,domain.grid.tuning.tile_metres))
			add_child(view)
			views[key] = {"view":view,"material":tile_material,"revision":-1,"stamp":"","state":null,"motion":null}
		var entry: Dictionary = views[key]
		entry.view.visible = true
		entry.material.set_shader_parameter("blend",blend)
		entry.material.set_shader_parameter("emitters",interactions)
		# Neighbor revisions matter at shared vertices. Update all resident tile
		# textures together; a slow render frame must never leave a stale edge.
		var stamp := str(tile.revision)
		for direction: Vector2i in [Vector2i.RIGHT,Vector2i.DOWN,Vector2i.ONE]:
			var neighbor: WaterTile = domain.grid.tiles.get(key+direction)
			stamp += ":"+str(neighbor.revision if neighbor != null else -1)
		if entry.stamp != stamp:
			_upload(tile,entry)
			entry.stamp = stamp
			entry.revision = tile.revision
	rebuild_ms = (Time.get_ticks_usec()-started)/1000.0
	worst_mesh_ms = maxf(worst_mesh_ms,rebuild_ms)
func _mesh(tile: WaterTile) -> ArrayMesh:
	var n := tile.side
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	var spacing := float(domain.grid.tuning.cell_metres)
	for z: int in range(n+1):
		for x: int in range(n+1):
			vertices.append(Vector3((tile.coord.x*n+x)*spacing,0,(tile.coord.y*n+z)*spacing))
			normals.append(Vector3.UP)
			uv.append(Vector2(x,z))
	for z: int in n:
		for x: int in n:
			var i := z*(n+1)+x
			indices.append_array(PackedInt32Array([i,i+n+1,i+1,i+1,i+n+1,i+n+2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
func _upload(tile: WaterTile, entry: Dictionary) -> void:
	var n := tile.side
	var state := PackedFloat32Array()
	var motion := PackedFloat32Array()
	state.resize((n+1)*(n+1)*4)
	motion.resize((n+1)*(n+1)*2)
	for z: int in range(n+1):
		for x: int in range(n+1):
			var source := tile
			var i := z*n+x
			if z == n or x == n:
				var cell := tile.coord*n+Vector2i(x,z)
				source = domain.grid.tiles.get(domain.grid.address(cell),tile)
				i = domain.grid.index(cell) if source != tile else mini(z,n-1)*n+mini(x,n-1)
			var level: float = source.ground[i]+source.depth[i] if source.depth[i] > domain.grid.tuning.dry_depth else source.rest_level[i]
			var vertex := z*(n+1)+x
			state[vertex*4] = level
			state[vertex*4+1] = level+source.previous[i]-source.depth[i]
			state[vertex*4+2] = source.depth[i]
			motion[vertex*2] = source.flow_x[i]
			motion[vertex*2+1] = source.flow_z[i]
	var image := Image.create_from_data(n+1,n+1,false,Image.FORMAT_RGBAF,state.to_byte_array())
	var flow := Image.create_from_data(n+1,n+1,false,Image.FORMAT_RGF,motion.to_byte_array())
	if entry.state == null:
		entry.state = ImageTexture.create_from_image(image)
		entry.motion = ImageTexture.create_from_image(flow)
		entry.material.set_shader_parameter("state_map",entry.state)
		entry.material.set_shader_parameter("motion_map",entry.motion)
	else:
		entry.state.update(image)
		entry.motion.update(flow)
func report() -> Dictionary:
	return {"water_nodes":views.size()+2,"water_cells":domain.grid.tiles.size()*domain.grid.side()*domain.grid.side(),"tile_meshes":views.size(),"last_mesh_ms":rebuild_ms,"worst_mesh_ms":worst_mesh_ms,"state_texture_bytes":views.size()*(domain.grid.side()+1)*(domain.grid.side()+1)*24}
func set_interactions(points: Array[Vector4]) -> void:
	emitters = points.slice(0,ripple_cap)
func _waterfalls() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var count := 0
	for edge: Dictionary in domain.grid.waterfalls:
		var a: Vector3 = edge.from
		var b: Vector3 = edge.to
		if a.y-b.y < float(domain.grid.tuning.waterfall_drop):
			continue
		var side := Vector3(b.z-a.z,0,a.x-b.x).normalized()*.7
		for point: Vector3 in [a-side,a+side,b+side,a-side,b+side,b-side]:
			tool.set_normal(Vector3.UP)
			tool.set_uv(Vector2(1,0))
			tool.set_uv2(Vector2(0,-2))
			tool.add_vertex(point)
		count += 1
	falls.mesh = tool.commit() if count > 0 else null
