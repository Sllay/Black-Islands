class_name WorldSession
extends Node3D
## Composition root for this save's world, not a global gameplay singleton.

var terrain: VoxelTerrainAdapter
var pawn: DebugWorldPawn
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

var grid_debug_visible := false

func _ready() -> void:
	if get_tree().has_meta("ui_only_smoke"):
		return
	_started = Time.get_ticks_msec()
	var profile := Profiles.current_profile()
	if profile.is_empty():
		return
	var storage_root := "user://worlds" if Profiles.store.directory == "user://profiles" else "user://qa_worlds"
	store = WorldDeltaStore.new(storage_root.path_join(profile.save_id), profile)
	var error := store.load_world()
	if error != OK:
		_show_load_error(error)
		return
	terrain = load("res://scenes/world/WorldTerrain.tscn").instantiate()
	terrain.field = IslandField.new(int(profile.world_seed))
	terrain.deltas = store
	add_child(terrain)
	water = WorldWater.new()
	water.terrain = terrain
	edits = TerrainEditService.new()
	edits.terrain = terrain
	edits.store = store
	edits.terrain_changed.connect(water.invalidate_terrain)
	pawn = load("res://scenes/debug/DebugWorldPawn.tscn").instantiate()
	pawn.terrain = terrain
	pawn.water = water
	add_child(pawn)
	streamer = WorldStreamer.new()
	streamer.name = "WorldStreamer"
	streamer.field = terrain.field
	streamer.viewer = pawn
	add_child(streamer)
	var lake := terrain.field.lake_body()
	$Lake.position = Vector3(lake.center.x, lake.level, lake.center.y)
	if OS.is_debug_build():
		_create_tools()
	print("WORLD seed=", profile.world_seed, " generation=", profile.world_generation_version, " profile=", profile.world_profile, " deltas=", store.metrics())

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
	var point := pawn.global_position + Vector3(0, 0, -4)
	var hit := terrain.surface_hit(point.x, point.z)
	if hit.is_empty():
		return false
	if edits.apply(hit.position, 2, paint, 2) != OK:
		return false
	_observe_edit(edits.last_result.duplicate(), hit.position.y)
	return true

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
	return {"seed": terrain.field.world_seed, "generation": IslandField.VERSION, "profile": IslandField.PROFILE_ID,
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
	panel.position = Vector2(-215, 20)
	panel.theme = load("res://resources/ui/ShellTheme.tres")
	canvas.add_child(panel)
	var toggle := ShellUI.button("QA WORLD • F2 / F4 Grade", "WorldTools", Vector2(200, 42))
	panel.add_child(toggle)
	tools = ShellUI.column(panel, 6)
	tools.visible = false
	toggle.pressed.connect(func() -> void: tools.visible = not tools.visible)
	metrics_label = ShellUI.label_text("", 16)
	tools.add_child(metrics_label)
	for entry: Array in [["F • Escavar", func() -> void: edit_ahead(false)], ["P • Pintar solo", func() -> void: edit_ahead(true)], ["F3 • Panorama", pawn.toggle_overview], ["Borda 64m", func() -> void: pawn.inspect_at(Vector3(74, 40, 0))], ["Praia", func() -> void: pawn.inspect_at(Vector3(199, 40, 0))], ["Oceano / limite suave", func() -> void: pawn.inspect_at(Vector3(380, 2, 0))], ["Clareira", func() -> void: pawn.inspect_at(Vector3(0, 40, 0))]]:
		var button := ShellUI.button(entry[0], "QA", Vector2(200, 44))
		button.pressed.connect(entry[1])
		tools.add_child(button)

func _process(delta: float) -> void:
	if terrain == null:
		return
	if ready_ms < 0 and pawn.spawned:
		var jobs: Dictionary = terrain.statistics().engine.tasks
		if jobs.generation == 0 and jobs.meshing == 0 and jobs.main_thread == 0:
			ready_ms = Time.get_ticks_msec() - _started
			print("WORLD_READY ", ready_ms, "ms")
	if metrics_label == null:
		return
	_refresh += delta
	if _refresh < 0.25:
		return
	_refresh = 0
	$BuildHighlight.visible = grid_debug_visible
	if grid_debug_visible:
		var point := pawn.global_position + Vector3(0, 0, -4)
		var hit := terrain.surface_hit(point.x, point.z)
		if not hit.is_empty():
			var cell := WorldCoordinates.world_to_cell(hit.position)
			$BuildHighlight.position = Vector3(cell.x + 0.5, hit.position.y + 0.06, cell.z + 0.5)
	var report := terrain.statistics()
	var ring := streamer.metrics()
	var water_sample := water.sample(pawn.global_position)
	metrics_label.text = "P02 DEBUG • DESKTOP PROXY\nseed %s • cell %s\nregions %s • chunks %s • pending %s\nloads %s • unloads %s • transition %sms\nnative data %s • meshes %s\njobs gen %s / mesh %s • pool %.1f MiB\nremesh confirmations %s • collision %s\ndelta %s voxels • water %s\nedit commit %sms / mesh %sms / collision %sms" % [terrain.field.world_seed, WorldCoordinates.world_to_cell(pawn.global_position), ring.horizontal_regions, ring.loaded_chunks, ring.pending_jobs, ring.applied, ring.unloaded, ring.transition_ms, report.data_blocks, report.mesh_blocks, report.engine.tasks.generation, report.engine.tasks.meshing, report.engine.memory_pools.voxel_total / 1048576.0, remesh_confirmations, collision_confirmations, store.metrics().changed_voxels, water_sample.kind, last_edit.get("commit_ms", "-"), last_edit.get("mesh_ms", "-"), last_edit.get("collision_ms", "-")]
