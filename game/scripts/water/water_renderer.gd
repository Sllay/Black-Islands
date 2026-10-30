class_name WaterRenderer
extends Node3D
## Grouped tile meshes. Simulation is independent; no shader feeds gameplay.
var domain: WaterDomain
var views: Dictionary = {}
var material: ShaderMaterial
var quality := "Medium"
var rebuild_ms := 0.0
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
	if material != null:
		var visual: Dictionary = profile.get("water",{"wave":.04,"foam":.4,"ripples":2})
		material.set_shader_parameter("wave_amplitude",float(visual.wave))
		material.set_shader_parameter("foam_strength",float(visual.foam))
		ripple_cap = clampi(int(visual.ripples),0,4)
		var ocean: ShaderMaterial = load("res://resources/world/OceanMaterial.tres")
		ocean.set_shader_parameter("wave_amplitude",float(visual.wave))
		ocean.set_shader_parameter("foam_strength",float(visual.foam))
func _process(delta: float) -> void:
	if domain == null or material == null:
		return
	material.set_shader_parameter("blend",clampf(domain.accumulator*domain.grid.tuning.solver_hz,0,1))
	var interactions := PackedVector4Array()
	for emitter: Vector4 in emitters.slice(0,ripple_cap):
		interactions.append(emitter)
	if domain.observer != null and interactions.size() < ripple_cap:
		var point := domain.observer.global_position
		if domain.grid.sample(point).get("depth",0) > .1:
			interactions.append(Vector4(point.x,point.y,point.z,1))
	while interactions.size() < 4:
		interactions.append(Vector4.ZERO)
	material.set_shader_parameter("emitters",interactions)
	_fall_tick += delta
	if _fall_tick >= .1:
		_fall_tick = 0
		_waterfalls()
	for key: Vector2i in domain.grid.tiles:
		var tile: WaterTile = domain.grid.tiles[key]
		if tile.activity == WaterTile.Activity.INACTIVE:
			if views.has(key):
				views[key].view.visible = false
			continue
		if not views.has(key):
			var view := MeshInstance3D.new()
			view.material_override = material
			view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(view)
			views[key] = {"view":view,"revision":-1}
		views[key].view.visible = true
		if views[key].revision != tile.revision:
			var started := Time.get_ticks_usec()
			views[key].view.mesh = _mesh(tile)
			views[key].revision = tile.revision
			rebuild_ms = (Time.get_ticks_usec()-started)/1000.0
			break # One bounded tile rebuild per rendered frame.
func _mesh(tile: WaterTile) -> ArrayMesh:
	var n := tile.side
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var flow := PackedVector2Array()
	var uv := PackedVector2Array()
	var indices := PackedInt32Array()
	for z: int in range(n+1):
		for x: int in range(n+1):
			var i := mini(z,n-1)*n+mini(x,n-1)
			var point := Vector3((tile.coord.x*n+x)*domain.grid.tuning.cell_metres,tile.ground[i]+tile.depth[i]+.025,(tile.coord.y*n+z)*domain.grid.tuning.cell_metres)
			vertices.append(point)
			normals.append(Vector3.UP)
			flow.append(Vector2(tile.flow_x[i],tile.flow_z[i]))
			uv.append(Vector2(tile.depth[i],tile.previous[i]-tile.depth[i]))
	for z: int in n:
		for x: int in n:
			var i := z*(n+1)+x
			indices.append_array(PackedInt32Array([i,i+n+1,i+1,i+1,i+n+1,i+n+2]))
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV2] = flow
	arrays[Mesh.ARRAY_TEX_UV] = uv
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	return mesh
func report() -> Dictionary:
	return {"water_nodes":views.size()+2,"water_cells":domain.grid.tiles.size()*domain.grid.side()*domain.grid.side(),"tile_meshes":views.size(),"last_mesh_ms":rebuild_ms}

func set_interactions(points: Array[Vector4]) -> void:
	# Main-thread bounded presentation input; never modifies authoritative water.
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
