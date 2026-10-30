extends Node3D
## P03-compatible view/seed/budgets; attaches only P04 services to the same pawn.
class SessionHarness extends WorldSession:
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass # Composition-only fixture has no WorldSession presentation children.

var baseline: Node3D
var surface: SurfaceRuntime
var _harvesting := false
var _harvest_clock := 0.0

func _process(delta: float) -> void:
	if not _harvesting:
		return
	_harvest_clock += delta
	if _harvest_clock >= 1:
		_harvest_clock = 0
		surface.qa_resource("tree","bi.tool.axe")

func _ready() -> void:
	baseline = load("res://scenes/debug/P03PlayerBenchmark.tscn").instantiate()
	baseline.name = "Baseline"
	add_child(baseline)
	var session := SessionHarness.new()
	session.terrain = baseline.terrain
	session.pawn = baseline.pawn
	session.water = baseline.water
	session.streamer = baseline.streamer
	var profile := {"save_id":"04040404040404040404040404040499","created_at":"2026-10-29T00:00:00Z",
		"world_seed":424242,"world_generation_version":1,"world_profile":IslandField.PROFILE_ID}
	session.store = WorldDeltaStore.new("user://qa_p04_benchmark",profile)
	session.store.load_world()
	session.edits = TerrainEditService.new()
	session.edits.terrain = baseline.terrain
	session.edits.store = session.store
	add_child(session)
	surface = SurfaceRuntime.new()
	surface.name = "Surface"
	session.add_child(surface)
	surface.configure(session)
	print("P04_BENCHMARK DESKTOP PROXY ONLY seed424242 / matched P03 camera")

func prepare(scenario: String) -> void:
	baseline.stop_inputs()
	_harvesting = scenario == "harvest"
	if scenario == "harvest":
		surface.qa_resource("tree","bi.tool.axe")
	elif scenario == "structure":
		surface.deliver({"bi.resource.wood":100},surface.player.position)
		surface.qa.c02()
	elif scenario == "mobs":
		surface.qa.c03()
		for pair: Array in [["chicken",Vector3(35,0,0)],["boar",Vector3(70,0,0)],["zombie",Vector3(160,0,0)]]:
			var point: Vector3 = surface.player.position+pair[1]
			point.y = surface.terrain.field.top_surface(point.x,point.z)+.05
			surface.mobs.domain.spawn(surface.ledger.new_id("perf_mob"),pair[0],point)
		surface.mobs.reconcile()
	elif scenario == "steady_mob_free":
		for state: Dictionary in surface.mobs.domain.states.values():
			state.life = "REMOVED"
		surface.mobs.reconcile()

func report() -> Dictionary:
	return {"baseline":baseline.bench_report(),"surface":surface.report(),
		"surface_bytes":JSON.stringify(surface.snapshot()).length()}
