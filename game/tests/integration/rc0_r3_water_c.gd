extends Node3D
## Focused synthetic water acceptance/performance probe, independent of terrain cost.
## Keep open with R3_WATER_KEEP_OPEN=1 for real MCP inspection/screenshots.
@export var keep_open := false
var failures := 0
var domain: WaterDomain
var renderer: WaterRenderer
var camera: Camera3D
var barrier := false
var mode := "basin"
var frame_times: Array[float] = []
var measurements: Dictionary = {}

func check(ok: bool, label: String) -> void:
	if not ok:
		failures += 1
		push_error("R3_WATER_C "+label)

func _ready() -> void:
	Engine.max_fps = 60
	_run.call_deferred()

func _run() -> void:
	measurements.active_solver = _benchmark(false)
	measurements.sleeping_solver = _benchmark(true)
	_profiles()
	_fairness()
	domain = WaterDomain.new()
	domain.name = "WaterDomain"
	domain.grid.height_sample = _terrain_height
	domain.grid.initial_water = func(_point: Vector3) -> Dictionary: return {"kind":"lake","level":1.0}
	add_child(domain)
	domain.grid.ensure_tile(Vector2i.ZERO)
	renderer = WaterRenderer.new()
	renderer.name = "WaterRenderer"
	renderer.domain = domain
	add_child(renderer)
	_create_view()
	qa_quality(OS.get_environment("R3_WATER_QUALITY") if not OS.get_environment("R3_WATER_QUALITY").is_empty() else "Medium")
	for frame: int in 120:
		await get_tree().process_frame
		if frame > 30:
			frame_times.append(get_process_delta_time()*1000)
	check(renderer.get_child_count() <= 4,"presentation is grouped by tile, not by cell")
	check(domain.grid.side()*domain.grid.side() == 1024,"production 64m / 2m tile cell count")
	measurements.rendering = performance_report()
	measurements.renderer_off = await _render_pass(false)
	measurements.renderer_on = await _render_pass(true)
	if not OS.get_environment("R3_WATER_CAPTURE").is_empty() and DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(OS.get_environment("R3_WATER_CAPTURE"))
	print("R3_WATER_METRICS ",JSON.stringify(measurements))
	print("R3_WATER_C ","PASS" if failures == 0 else "FAIL"," failures=",failures," rendering_method=",RenderingServer.get_current_rendering_method())
	if not keep_open and OS.get_environment("R3_WATER_KEEP_OPEN") != "1":
		get_tree().quit(1 if failures else 0)

func _benchmark(sleeping: bool) -> Dictionary:
	var grid := WaterGrid.new()
	grid.height_sample = func(_point: Vector3) -> float: return 0.0
	grid.initial_water = func(_point: Vector3) -> Dictionary: return {"kind":"lake","level":1.0}
	var tile := grid.ensure_tile(Vector2i.ZERO)
	var start_volume := grid.volume()
	var times: Array[float] = []
	for tick: int in 120:
		if not sleeping:
			# Move volume inside the basin without creating any, keeping the solver active.
			tile.depth[10] += .01
			tile.depth[100] -= .01
			tile.wake()
		grid.step(1.0/float(grid.tuning.solver_hz))
		times.append(grid.last_ms)
	check(absf(grid.volume()-start_volume) < .02,"benchmark conserves volume")
	check(grid.last_cells == (0 if sleeping else tile.depth.size()),"active versus sleeping solver cell accounting")
	var result := _summary(times)
	result.merge(grid.report())
	result.cells = tile.depth.size()
	return result

func _profiles() -> void:
	var expected := PackedFloat32Array()
	for quality: String in ["Low","Medium","High"]:
		var settings := GameSettings.staged_copy()
		settings.quality = quality
		var budget := GraphicsBudget.resolve(settings,GameSettings.catalog)
		check(budget.has("water"),"water profile exists "+quality)
		var grid := WaterGrid.new()
		grid.tuning.tile_metres = 8
		grid.tuning.cell_metres = 1
		grid.height_sample = func(point: Vector3) -> float: return -.1*point.x
		var tile := grid.ensure_tile(Vector2i.ZERO)
		grid.add_water(Vector3(2,0,2),4)
		for tick: int in 90:
			grid.step(1.0/float(grid.tuning.solver_hz))
		if expected.is_empty():
			expected = tile.depth.duplicate()
		else:
			check(expected == tile.depth,"graphics profile does not change water gameplay "+quality)

func _summary(values: Array[float]) -> Dictionary:
	var sorted := values.duplicate()
	sorted.sort()
	var total := 0.0
	for value: float in sorted:
		total += value
	return {"samples":sorted.size(),"mean_ms":total/maxi(1,sorted.size()),"p95_ms":sorted[mini(sorted.size()-1,floori(sorted.size()*.95))] if not sorted.is_empty() else 0.0,"max_ms":sorted.back() if not sorted.is_empty() else 0.0}

func _create_view() -> void:
	var ground := MeshInstance3D.new()
	ground.name = "BasinGround"
	var plane := PlaneMesh.new()
	plane.size = Vector2(68,68)
	ground.mesh = plane
	ground.position = Vector3(32,-.1,32)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(.33,.38,.22)
	ground.material_override = material
	add_child(ground)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55,-30,0)
	light.light_energy = 1.2
	add_child(light)
	var environment := WorldEnvironment.new()
	var sky := Environment.new()
	sky.background_mode = Environment.BG_COLOR
	sky.background_color = Color(.45,.64,.72)
	sky.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	sky.ambient_light_color = Color(.7,.8,.9)
	sky.ambient_light_energy = .6
	environment.environment = sky
	add_child(environment)
	camera = Camera3D.new()
	camera.name = "Camera"
	camera.position = Vector3(80,57,80)
	camera.far = 400
	add_child(camera)
	camera.look_at(Vector3(32,0,32))
	camera.current = true

func _terrain_height(point: Vector3) -> float:
	if mode == "basin":
		return 0.0
	if barrier and point.x >= 30 and point.x <= 34:
		return 7.0
	return 3.0 if point.x < 24 else -1.0

func qa_flow() -> void:
	mode = "flow"
	barrier = false
	_reset_demo()
	domain.grid.sources[Vector2i(11,16)] = {"rate":2.0,"level":4.5}

func qa_block() -> void:
	mode = "flow"
	barrier = true
	_reset_demo()

func qa_release() -> void:
	barrier = false
	_update_ground()
	domain.grid.invalidate(AABB(Vector3(28,-10,0),Vector3(8,20,64)))

func _reset_demo() -> void:
	domain.grid.tiles.clear()
	var tile := domain.grid.ensure_tile(Vector2i.ZERO)
	for i: int in tile.depth.size():
		var x: float = (i%tile.side+.5)*domain.grid.tuning.cell_metres
		tile.depth[i] = 0.0 if barrier and x >= 30 and x <= 34 else (1.5 if x < 24 else .15)
		tile.previous[i] = tile.depth[i]
	tile.revision += 1
	tile.wake()
	_update_ground()
	for key: Variant in renderer.views:
		renderer.views[key].revision = -1

func qa_quality(quality: String) -> void:
	var settings := GameSettings.staged_copy()
	settings.quality = quality
	renderer.apply_profile(GraphicsBudget.resolve(settings,GameSettings.catalog))

func performance_report() -> Dictionary:
	var result := _summary(frame_times)
	result.rendering_method = RenderingServer.get_current_rendering_method()
	result.water = domain.grid.report()
	result.presentation = renderer.report()
	result.nodes = _node_count(self)
	result.draw_calls = Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	result.render_objects = Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	result.render_primitives = Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	result.static_memory_bytes = Performance.get_monitor(Performance.MEMORY_STATIC)
	return result

func _node_count(node: Node) -> int:
	var count := 1
	for child: Node in node.get_children():
		count += _node_count(child)
	return count

func _render_pass(enabled: bool) -> Dictionary:
	renderer.visible = enabled
	renderer.set_process(enabled)
	Engine.max_fps = 0
	for warm: int in 15:
		await get_tree().process_frame
	var values: Array[float] = []
	for frame: int in 60:
		await get_tree().process_frame
		values.append(get_process_delta_time()*1000)
	var result := _summary(values)
	result.draw_calls = RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	result.method = RenderingServer.get_current_rendering_method()
	Engine.max_fps = 60
	return result

func _update_ground() -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z: int in range(0,64,2):
		for x: int in range(0,64,2):
			for corner: Vector2 in [Vector2(x,z),Vector2(x,z+2),Vector2(x+2,z),Vector2(x+2,z),Vector2(x,z+2),Vector2(x+2,z+2)]:
				var p := Vector3(corner.x,0,corner.y)
				p.y = _terrain_height(p)-.1
				tool.add_vertex(p)
	tool.generate_normals()
	$BasinGround.position = Vector3.ZERO
	$BasinGround.mesh = tool.commit()

func _fairness() -> void:
	var test_domain := WaterDomain.new()
	test_domain.grid.tuning.tile_metres = 8
	test_domain.grid.tuning.cell_metres = 1
	test_domain.grid.height_sample = func(_p: Vector3) -> float: return 0
	test_domain.grid.initial_water = func(_p: Vector3) -> Dictionary: return {"kind":"lake","level":1}
	var a := test_domain.grid.ensure_tile(Vector2i.ZERO)
	var b := test_domain.grid.ensure_tile(Vector2i.RIGHT)
	b.depth[24] = 3.0
	b.previous[24] = 1.0
	add_child(test_domain)
	test_domain.set_process(false)
	var view := WaterRenderer.new()
	view.domain = test_domain
	add_child(view)
	view.set_process(false)
	for tick: int in 8:
		a.revision += 1
		b.revision += 1
		view._process(.016)
	check(view.views.size() == 2 and view.views[Vector2i.ZERO].revision >= 7 and view.views[Vector2i.RIGHT].revision >= 7,"render budget cannot starve a later active tile")
	var left: Image = view.views[Vector2i.ZERO].state.get_image()
	var right: Image = view.views[Vector2i.RIGHT].state.get_image()
	check(left.get_pixel(8,3) == right.get_pixel(0,3),"shared edge current/previous/depth state is identical")
	check(view.views[Vector2i.ZERO].material.get_shader_parameter("blend") == view.views[Vector2i.RIGHT].material.get_shader_parameter("blend"),"shared interpolation phase is identical")
	view.free()
	test_domain.free()
