extends Node3D
## Matched QA control: same seed/terrain/ring/view/lighting, old P02 pawn vs P03.
## Never a production switch or a change to the world's streaming configuration.
@export var legacy := false
var terrain: VoxelTerrainAdapter
var pawn: CharacterBody3D
var streamer: WorldStreamer
var water: WorldWater
var save_coordinator: PlayerSaveCoordinator
var warmed := false
var _poll := 0.0
var _combat := false
var _combat_clock := 0.0
var _tap_time := 0.0
var _dodge_clock := 0.0
var _dummy: CombatDummy

func _ready() -> void:
	var shell: Node3D = load("res://scenes/world/WorldSession.tscn").instantiate()
	shell.set_script(null)
	add_child(shell)
	terrain = load("res://scenes/world/WorldTerrain.tscn").instantiate()
	terrain.field = IslandField.new(424242)
	add_child(terrain)
	water = WorldWater.new()
	water.terrain = terrain
	pawn = load("res://scenes/debug/DebugWorldPawn.tscn" if legacy else "res://scenes/player/Player.tscn").instantiate()
	pawn.terrain = terrain
	pawn.water = water
	add_child(pawn)
	if not legacy:
		var player := pawn as PlayerActor
		player.camera_rig.benchmark_legacy = true
		var directory := "user://qa_p03_perf_state"
		for suffix: String in ["", ".bak", ".tmp"]:
			var path := directory.path_join("player.json"+suffix)
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)
		var profile := {"save_id":"03030303030303030303030303030344", "created_at":"2026-10-29T00:00:00Z",
			"world_seed":424242,"world_generation_version":1,"world_profile":IslandField.PROFILE_ID}
		var store := PlayerSaveStore.new(directory,profile)
		assert(store.load_player() == OK)
		save_coordinator = PlayerSaveCoordinator.new()
		add_child(save_coordinator)
		save_coordinator.configure(player,store)
	streamer = WorldStreamer.new()
	streamer.field = terrain.field
	streamer.viewer = pawn
	add_child(streamer)
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var hud: Control = load("res://scenes/ui/ProductionHUD.tscn").instantiate()
	canvas.add_child(hud)
	hud.present_world()
	print("BENCH seed=424242 legacy=",legacy," DESKTOP PROXY ONLY")

func _process(delta: float) -> void:
	_poll += delta
	if _poll >= 0.25:
		_poll = 0
		var jobs: Dictionary = terrain.statistics().engine.tasks
		if not warmed and bool(pawn.get("spawned")) and jobs.generation == 0 and jobs.meshing == 0 and jobs.main_thread == 0:
			warmed = true
			print("BENCH_READY ",bench_report())
	if not _combat:
		return
	_combat_clock += delta
	_dodge_clock += delta
	if _tap_time > 0:
		_tap_time -= delta
		if _tap_time <= 0:
			Input.action_release("attack_primary")
	elif _combat_clock >= 0.9:
		_combat_clock = 0
		_tap_time = 0.08
		Input.action_press("attack_primary")
	# Keep dodge cadence out of the sword's active/recovery windows.
	if _dodge_clock >= 2.65:
		_dodge_clock = 0
		Input.action_press("dodge")
	else:
		Input.action_release("dodge")

func place(point: Vector3) -> void:
	stop_inputs()
	pawn.inspect_at(point)
	warmed = false
	if pawn is PlayerActor:
		pawn.state.set_stamina(100)

func combat_loop(enabled: bool) -> void:
	stop_inputs()
	_combat = enabled
	if enabled:
		if is_instance_valid(_dummy):
			_dummy.queue_free()
		_dummy = load("res://scenes/debug/CombatDummy.tscn").instantiate()
		_dummy.max_health = 10000
		var point := pawn.global_position+Vector3.FORWARD*1.6
		var surface := terrain.surface_hit(point.x,point.z)
		_dummy.position = surface.position+Vector3.UP*0.03
		add_child(_dummy)
		if pawn is PlayerActor:
			pawn.motor.facing = Vector3.FORWARD
			pawn.state.set_stamina(100)

func stop_inputs() -> void:
	_combat = false
	_tap_time = 0
	for action: StringName in [&"attack_primary",&"dodge",&"move_right",&"run"]:
		Input.action_release(action)

func bench_report() -> Dictionary:
	return {"legacy":legacy,"ready":warmed,"seed":424242,"position":pawn.global_position,
		"ring":streamer.metrics(),"terrain":terrain.statistics(),"distance":pawn.get("distance_travelled"),
		"lpc":LPCCompositionCache.report(),"combat":pawn.combat.report() if pawn is PlayerActor else {},
		"save_ms":save_coordinator.last_commit_ms if save_coordinator != null else 0}
