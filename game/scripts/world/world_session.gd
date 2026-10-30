class_name WorldSession
extends Node3D
## Composition root for this save's world, not a global gameplay singleton.

var terrain: VoxelTerrainAdapter
var pawn: PlayerActor
var streamer: WorldStreamer
var metrics_label: Label
var tools: VBoxContainer
var _refresh := 0.0

var store: WorldDeltaStore
var edits: TerrainEditService
var water: WorldWater
var grid := BuildGrid.new()
var ready_ms := -1
var remesh_confirmations := 0
var collision_confirmations := 0
var last_edit: Dictionary = {}
var _started := 0
var terrain_saver: TerrainSaveScheduler
var residency_anchor: TerrainResidencyAnchor

var grid_debug_visible := false

var player_store: PlayerSaveStore
var player_save: PlayerSaveCoordinator
var qa_dummy: CombatDummy
var player_metrics: Label

var surface: SurfaceRuntime
var frontend_save: FrontendSessionSave
var preview: WorldPreview

func _ready() -> void:
	if get_tree().has_meta("ui_only_smoke"):
		return
	_started = Time.get_ticks_msec()
	var profile := Profiles.current_profile()
	if profile.is_empty():
		return
	if not WorldGenerationProfile.supported(int(profile.get("world_generation_version",0)),str(profile.get("world_profile",""))):
		_show_load_error(ERR_UNAVAILABLE)
		return
	var storage_root := "user://worlds" if Profiles.store.directory == "user://profiles" else "user://qa_worlds"
	if Profiles.world_slot > 0:
		frontend_save = FrontendSessionSave.new()
		var preparation := frontend_save.prepare(Profiles.library,Profiles.world_slot,Profiles.player_slot)
		if preparation != OK:
			_show_load_error(preparation)
			return
		storage_root = Profiles.library.world_directory(profile).get_base_dir()
	store = BufferedWorldDeltaStore.new(storage_root.path_join(profile.save_id),profile)
	var error := store.load_world()
	if error != OK:
		_show_load_error(error)
		return
	player_store = frontend_save.portable if frontend_save != null else PlayerSaveStore.new(store.directory,profile)
	error = player_store.load_player()
	if error != OK:
		_show_load_error(error)
		return
	if frontend_save != null and not profile.generated:
		var metadata := Profiles.library.document("world",Profiles.world_slot)
		error = metadata.read()
		if error == OK:
			metadata.loaded.generated = true
			error = metadata.commit(metadata.loaded)
		if error != OK:
			_show_load_error(error)
			return
	terrain = load("res://scenes/world/WorldTerrain.tscn").instantiate()
	terrain.field = WorldGenerationProfile.field(int(profile.world_seed),int(profile.world_generation_version),str(profile.world_profile))
	WorldBoundary.configure_field(terrain.field)
	terrain.deltas = store
	add_child(terrain)
	water = WorldWater.new()
	water.terrain = terrain
	water.domain = WaterDomain.new()
	water.domain.name = "WaterDomain"
	water.domain.configure(terrain)
	add_child(water.domain)
	edits = TerrainEditService.new()
	edits.terrain = terrain
	edits.store = store
	edits.terrain_changed.connect(water.invalidate_terrain)
	edits.operation_completed.connect(func(operation: Dictionary) -> void: _observe_edit(operation,float(operation.center.y)))
	pawn = load("res://scenes/player/Player.tscn").instantiate()
	pawn.terrain = terrain
	pawn.water = water
	water.domain.observer = pawn
	add_child(pawn)
	player_save = frontend_save if frontend_save != null else PlayerSaveCoordinator.new()
	player_save.name = "PlayerSave"
	add_child(player_save)
	player_save.configure(pawn,player_store)
	terrain_saver = TerrainSaveScheduler.new()
	terrain_saver.name = "TerrainSaveScheduler"
	terrain_saver.store = store
	terrain_saver.edits = edits
	add_child(terrain_saver)
	player_save.terrain_saver = terrain_saver
	residency_anchor = TerrainResidencyAnchor.new()
	residency_anchor.name = "TerrainResidencyAnchor"
	add_child(residency_anchor)
	residency_anchor.configure(pawn,pawn.get_node("Viewer"))
	streamer = WorldStreamer.new()
	streamer.name = "WorldStreamer"
	streamer.field = terrain.field
	streamer.viewer = pawn
	add_child(streamer)
	_create_surface()
	edits.intent_queued.connect(func(_operation: Dictionary) -> void: surface.message.emit("Preparando o terreno próximo…"))
	edits.operation_failed.connect(func(_operation: Dictionary) -> void: surface.message.emit("Ação de terreno cancelada: área ainda indisponível ou alvo alterado."))
	GameSettings.apply_scene(self)
	apply_graphics(GameSettings.effective())
	if terrain.field is WorldFieldV2:
		$Lake.visible = false
		var waters := GeneratedWaterView.new()
		waters.field = terrain.field
		add_child(waters)
	else:
		var lake := terrain.field.lake_body()
		$Lake.position = Vector3(lake.center.x,lake.level,lake.center.y)
	if OS.is_debug_build():
		_create_tools()
		_create_player_qa()
	print("WORLD seed=",profile.world_seed," generation=",profile.world_generation_version," profile=",profile.world_profile," deltas=",store.metrics())

func _create_surface() -> void:
	surface = SurfaceRuntime.new()
	surface.name = "Surface"
	add_child(surface)
	surface.configure(self,frontend_save.restored_surface if frontend_save != null else player_store.loaded.get("surface",{}))
	if frontend_save != null:
		frontend_save.bind_surface(surface)
	if frontend_save != null and DisplayServer.get_name() != "headless":
		preview = WorldPreview.new()
		preview.session = self
		add_child(preview)
		_capture_preview()

func _capture_preview() -> void:
	while not pawn.spawned:
		await get_tree().process_frame
	await get_tree().create_timer(3).timeout
	await preview.capture()

func _unhandled_input(event: InputEvent) -> void:
	if pawn == null:
		return
	if event.is_action_pressed("debug_world_tools"):
		tools.visible = not tools.visible
	elif event.is_action_pressed("debug_world_grid"):
		grid_debug_visible = not grid_debug_visible
	elif event.is_action_pressed("debug_world_overview"):
		pawn.toggle_overview()
	elif event.is_action_pressed("debug_terrain_dig"):
		edit_ahead(false)
	elif event.is_action_pressed("debug_terrain_paint"):
		edit_ahead(true)

func edit_ahead(paint: bool) -> bool:
	if pawn == null:
		return false
	var target := pawn.targeter.current
	if target.kind not in [TargetResult.Kind.TERRAIN,TargetResult.Kind.BUILD_GRID]:
		return false
	return edits.request(target.world_position,2,paint,2,pawn) == OK

func _observe_edit(operation: Dictionary, before_y: float) -> void:
	var deadline := Time.get_ticks_msec() + 10000
	var mesh_ms := -1
	var collision_ms := -1
	# A fresh post_edit notification has not necessarily reached native update
	# processing at the next physics signal. Drain two complete process cycles
	# before reading readiness, so an old UP_TO_DATE state cannot be counted.
	# These QA timings are observed upper bounds, not GPU completion timestamps.
	await get_tree().process_frame
	await get_tree().process_frame
	while Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		var area: AABB = operation.area
		var local := AABB(terrain.native.to_local(area.position), area.size / WorldCoordinates.VOXEL_SIZE)
		var tasks: Dictionary = terrain.statistics().engine.tasks
		if mesh_ms < 0 and terrain.native.is_area_meshed(local, 0) and tasks.meshing == 0 and tasks.main_thread == 0:
			mesh_ms = Time.get_ticks_msec() - int(operation.started_ms)
			remesh_confirmations += 1
		if not operation.paint and collision_ms < 0:
			var hit := terrain.surface_hit(operation.center.x, operation.center.z)
			if not hit.is_empty() and hit.position.y < before_y - 0.25:
				collision_ms = Time.get_ticks_msec() - int(operation.started_ms)
				collision_confirmations += 1
		if mesh_ms >= 0 and (operation.paint or collision_ms >= 0):
			break
	last_edit = operation
	last_edit["mesh_ms"] = mesh_ms
	last_edit["collision_ms"] = collision_ms
	print("WORLD_EDIT ", last_edit)

func session_report() -> Dictionary:
	if terrain == null:
		return {"ready": false}
	return {"seed": terrain.field.world_seed, "generation": terrain.field.generation_version, "profile": terrain.field.profile_id,
		"ready_ms": ready_ms, "ring": streamer.metrics(), "terrain": terrain.statistics(), "delta": store.metrics(),
		"remesh_confirmations": remesh_confirmations, "collision_confirmations": collision_confirmations,
		"last_edit": last_edit, "water": water.sample(pawn.global_position), "water_dirty": water.dirty_notifications}

func _show_load_error(error: Error) -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var box := VBoxContainer.new()
	box.position = Vector2(420, 220)
	box.theme = load("res://resources/ui/ShellTheme.tres")
	canvas.add_child(box)
	box.add_child(ShellUI.label_text("Não foi possível abrir esta ilha.\nSeus dados foram preservados.", 22))
	var back := ShellUI.button("Voltar às jornadas", "Return")
	back.pressed.connect(Flow.show_saves)
	box.add_child(back)
	push_error("World load rejected; original files preserved. Code: %s" % error)

func _create_tools() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "WorldQA"
	canvas.layer = 2
	add_child(canvas)
	var panel := VBoxContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.position = Vector2(-215,20)
	panel.theme = load("res://resources/ui/ShellTheme.tres")
	canvas.add_child(panel)
	var toggle := ShellUI.button("QA WORLD / PLAYER • F2","WorldTools",Vector2(200,42))
	panel.add_child(toggle)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(430,minf(570,get_viewport().get_visible_rect().size.y-120))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	tools = ShellUI.column(scroll,6)
	tools.visible = false
	scroll.visible = false
	tools.visibility_changed.connect(func() -> void: scroll.visible = tools.visible)
	toggle.pressed.connect(func() -> void: tools.visible = not tools.visible)
	metrics_label = ShellUI.label_text("",16)
	tools.add_child(metrics_label)
	for entry: Array in [["F • Escavar",func() -> void: edit_ahead(false)],["P • Pintar solo",func() -> void: edit_ahead(true)],["F3 • Panorama",pawn.toggle_overview],["Borda 64m",func() -> void: pawn.inspect_at(Vector3(74,40,0))],["Praia",func() -> void: pawn.inspect_at(Vector3(199,40,0))],["Oceano / limite suave",func() -> void: pawn.inspect_at(Vector3(380,2,0))],["Clareira",func() -> void: pawn.inspect_at(Vector3(0,40,0))]]:
		var button := ShellUI.button(entry[0],"QA",Vector2(200,44))
		button.pressed.connect(entry[1])
		tools.add_child(button)

func _create_player_qa() -> void:
	var row := HBoxContainer.new()
	tools.add_child(row)
	tools.move_child(row,0)
	for entry: Array in [["Alvo P03",spawn_combat_qa],["Pulso",pulse_combat_qa],["Reset alvo",reset_combat_qa]]:
		var button := ShellUI.button(entry[0],"PlayerQA",Vector2(110,44))
		button.pressed.connect(entry[1])
		row.add_child(button)
	player_metrics = ShellUI.label_text("",16)
	tools.add_child(player_metrics)
	tools.move_child(player_metrics,1)

func spawn_combat_qa() -> void:
	if pawn == null or not pawn.spawned:
		return
	if is_instance_valid(qa_dummy):
		qa_dummy.queue_free()
	var point := pawn.global_position+pawn.motor.facing*1.7
	var hit := terrain.surface_hit(point.x,point.z)
	if hit.is_empty():
		return
	qa_dummy = load("res://scenes/debug/CombatDummy.tscn").instantiate()
	qa_dummy.position = hit.position+Vector3.UP*0.04
	add_child(qa_dummy)

func pulse_combat_qa() -> void:
	if is_instance_valid(qa_dummy):
		qa_dummy.pulse_player(pawn)

func reset_combat_qa() -> void:
	if is_instance_valid(qa_dummy):
		qa_dummy.reset()
	pawn.state.set_health(pawn.state.max_health)
	pawn.state.set_stamina(pawn.state.max_stamina)
	pawn.combat.cancel()

func _process(delta: float) -> void:
	if terrain == null:
		return
	if ready_ms < 0 and pawn.spawned:
		var jobs: Dictionary = terrain.statistics().engine.tasks
		if jobs.generation == 0 and jobs.meshing == 0 and jobs.main_thread == 0:
			ready_ms = Time.get_ticks_msec() - _started
			print("WORLD_READY ", ready_ms, "ms")
	_update_placement_preview()
	if metrics_label == null or tools == null or not tools.visible:
		return
	_refresh += delta
	if _refresh < 0.25:
		return
	_refresh = 0
	if tools.visible and player_metrics != null:
		var combat_report := pawn.combat.report()
		var visual_report := pawn.visual.report()
		player_metrics.text = "P03 • pos %s\nvel %s • floor %s\ncamera %s • target %s\nLPC %s / %s • cache %s\ncombat %s • i-frame %s\nplayer save rev %d / %dms" % [pawn.global_position.snapped(Vector3.ONE*0.1),pawn.velocity.snapped(Vector3.ONE*0.1),pawn.is_on_floor(),"Build" if pawn.camera_rig.build_mode else "Gameplay",TargetResult.Kind.keys()[pawn.targeter.current.kind],visual_report.action,visual_report.direction,visual_report.cache.compositions,combat_report.phase,combat_report.invulnerable,player_store.revision,player_save.last_commit_ms]
	var report := terrain.statistics()
	var ring := streamer.metrics()
	var water_sample := water.sample(pawn.global_position)
	metrics_label.text = "P02 DEBUG • DESKTOP PROXY\nseed %s • cell %s\nregions %s • chunks %s • pending %s\nloads %s • unloads %s • transition %sms\nnative data %s • meshes %s\njobs gen %s / mesh %s • pool %.1f MiB\nremesh confirmations %s • collision %s\ndelta %s voxels • water %s\nedit commit %sms / mesh %sms / collision %sms" % [terrain.field.world_seed, WorldCoordinates.world_to_cell(pawn.global_position), ring.horizontal_regions, ring.loaded_chunks, ring.pending_jobs, ring.applied, ring.unloaded, ring.transition_ms, report.data_blocks, report.mesh_blocks, report.engine.tasks.generation, report.engine.tasks.meshing, report.engine.memory_pools.voxel_total / 1048576.0, remesh_confirmations, collision_confirmations, store.metrics().changed_voxels, water_sample.kind, last_edit.get("commit_ms", "-"), last_edit.get("mesh_ms", "-"), last_edit.get("collision_ms", "-")]

	var graphics := graphics_metrics()
	metrics_label.text += "\nRC0-R2 %s • draw %d • bodies %d\nfoliage %s • dirty chunks %d • %.1fms" % [graphics.profile.quality,graphics.draw_calls,graphics.physics_active_bodies,graphics.foliage.native_instances,graphics.dirty_chunks,graphics.frame_ms]

func _update_placement_preview() -> void:
	var target := pawn.targeter.current
	$BuildHighlight.visible = (grid_debug_visible or pawn.camera_rig.build_mode) and target.kind in [TargetResult.Kind.TERRAIN,TargetResult.Kind.BUILD_GRID]
	if not $BuildHighlight.visible:
		return
	var item := pawn.inventory.state.active_definition()
	if surface != null and item != null and item.category == "BUILDING_PIECE":
		var cell := surface.actions.snap_cell(target)
		$BuildHighlight.scale = Vector3(2,1,2)
		$BuildHighlight.position = StructureModule.center(cell)+Vector3.UP*(target.world_position.y-cell.y+.06)
	else:
		$BuildHighlight.scale = Vector3.ONE
		$BuildHighlight.position = Vector3(target.build_cell)+Vector3(.5,target.world_position.y-target.build_cell.y+.06,.5)

func apply_distance(level: int) -> void:
	var settings := GameSettings.staged_copy()
	settings.distance = clampi(level,2,10)
	settings.overrides.distance = true
	apply_graphics(GraphicsBudget.resolve(settings,GameSettings.catalog))

func apply_graphics(budget: Dictionary) -> void:
	if terrain == null or pawn == null:
		return
	terrain.native.view_distance = ceili(float(budget.viewer_metres)/WorldCoordinates.VOXEL_SIZE)
	pawn.get_node("Viewer").view_distance = int(budget.viewer_metres)
	streamer.set_radius(int(budget.near_ring))
	if surface != null and surface.foliage != null:
		surface.foliage.apply_profile(budget)

func graphics_metrics() -> Dictionary:
	var native := terrain.statistics()
	var io := store.metrics()
	return {"profile":GameSettings.effective(),"rendering_method":RenderingServer.get_current_rendering_method(),"data_slots":native.data_blocks,"mesh_slots":native.mesh_blocks,
		"voxel_buffer_bytes":native.engine.memory_pools.voxel_used,"generation_queue":native.engine.tasks.generation,
		"meshing_queue":native.engine.tasks.meshing,"dirty_chunks":io.get("dirty_chunks",0),
		"foliage":surface.foliage.report(),"active_mob_actors":surface.mobs.actors.size(),
		"physics_active_bodies":Performance.get_monitor(Performance.PHYSICS_3D_ACTIVE_OBJECTS),
		"frame_ms":Performance.get_monitor(Performance.TIME_PROCESS)*1000,
		"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		"static_memory_mib":Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0}
