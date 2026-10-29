class_name WorldSession
extends Node3D
## Composition root for this save's world, not a global gameplay singleton.

var terrain: VoxelTerrainAdapter
var pawn: DebugWorldPawn
var streamer: WorldStreamer
var metrics_label: Label
var tools: VBoxContainer
var _refresh := 0.0

func _ready() -> void:
	if get_tree().has_meta("ui_only_smoke"):
		return # Explicit P01 UI fixture; real world gates run separately.
	var profile := Profiles.current_profile()
	if profile.is_empty():
		return
	terrain = load("res://scenes/world/WorldTerrain.tscn").instantiate()
	terrain.field = IslandField.new(int(profile.world_seed))
	add_child(terrain)
	pawn = load("res://scenes/debug/DebugWorldPawn.tscn").instantiate()
	pawn.terrain = terrain
	add_child(pawn)
	streamer = WorldStreamer.new()
	streamer.name = "WorldStreamer"
	streamer.field = terrain.field
	streamer.viewer = pawn
	add_child(streamer)
	if OS.is_debug_build():
		_create_tools()
	print("WORLD seed=", profile.world_seed, " generation=", profile.world_generation_version, " profile=", profile.world_profile)

func _unhandled_input(event: InputEvent) -> void:
	if pawn == null:
		return
	if event.is_action_pressed("debug_world_tools"):
		tools.visible = not tools.visible
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
	return terrain.paint_sphere(hit.position, 2, 2) if paint else terrain.dig_sphere(hit.position, 2)

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
	var toggle := ShellUI.button("QA WORLD • F2", "WorldTools", Vector2(200, 42))
	panel.add_child(toggle)
	tools = ShellUI.column(panel, 6)
	tools.visible = false
	toggle.pressed.connect(func() -> void: tools.visible = not tools.visible)
	metrics_label = ShellUI.label_text("", 16)
	tools.add_child(metrics_label)
	for entry: Array in [["F • Escavar", func() -> void: edit_ahead(false)], ["P • Pintar solo", func() -> void: edit_ahead(true)], ["F3 • Panorama", pawn.toggle_overview], ["Borda 64m", func() -> void: pawn.inspect_at(Vector3(74, 40, 0))], ["Praia", func() -> void: pawn.inspect_at(Vector3(199, 40, 0))], ["Clareira", func() -> void: pawn.inspect_at(Vector3(0, 40, 0))]]:
		var button := ShellUI.button(entry[0], "QA", Vector2(200, 44))
		button.pressed.connect(entry[1])
		tools.add_child(button)

func _process(delta: float) -> void:
	if metrics_label == null:
		return
	_refresh += delta
	if _refresh < 0.5:
		return
	_refresh = 0
	var report := terrain.statistics()
	var ring := streamer.metrics()
	metrics_label.text = "P02 DEBUG • DESKTOP PROXY\nseed %s • cell %s\nregions %s • chunks %s • pending %s\nloads %s • unloads %s • transition %sms\nnative data %s • meshes %s\ngeneration %s • meshing %s\nnative pool %.1f MiB" % [terrain.field.world_seed, WorldCoordinates.world_to_cell(pawn.global_position), ring.horizontal_regions, ring.loaded_chunks, ring.pending_jobs, ring.applied, ring.unloaded, ring.transition_ms, report.data_blocks, report.mesh_blocks, report.engine.tasks.generation, report.engine.tasks.meshing, report.engine.memory_pools.voxel_total / 1048576.0]
