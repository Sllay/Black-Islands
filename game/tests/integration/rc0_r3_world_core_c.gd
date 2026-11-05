extends Node3D
var failures := 0
var assertions := 0
func check(ok: bool, text: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("WORLD_CORE_C "+text)
func _ready() -> void: _run.call_deferred()
func _run() -> void:
	var clock := WorldClock.new()
	check(clock.configure("world.test",WorldCore.tuning) == OK,"clock config")
	var events := {"time":0,"started":0,"ended":0,"period":0}
	clock.time_changed.connect(func(_seconds: float,_day: int,_phase: float) -> void: events.time += 1)
	clock.day_started.connect(func(_day: int) -> void: events.started += 1)
	clock.day_ended.connect(func(_day: int) -> void: events.ended += 1)
	clock.time_period_changed.connect(func(_period: String) -> void: events.period += 1)
	for tick: int in 60: clock.advance(1.0/60)
	check(events.time <= 1,"coarse time event, no per-frame subscribers")
	clock.paused = true
	var before := clock.elapsed_game_seconds
	clock.advance(5)
	check(clock.elapsed_game_seconds == before,"pause")
	clock.paused = false
	clock.time_scale = 2
	clock.advance(2)
	check(is_equal_approx(clock.elapsed_game_seconds,before+4),"time scale")
	var periods := {0.0:"DAWN",.2:"DAY",.55:"DUSK",.8:"NIGHT"}
	for phase: float in periods:
		var sample := WorldClock.new()
		sample.configure("period",WorldCore.tuning,phase*600)
		check(sample.period == periods[phase],"period "+periods[phase])
	clock.elapsed_game_seconds = 590
	clock.time_scale = 1
	clock.advance(20)
	check(clock.day == 2 and events.started == 1 and events.ended == 1 and events.period > 0,"day boundary events")
	clock.advance(6000)
	check(clock.pending_seconds > 5900,"bounded catch-up retains debt")
	var clock_copy := WorldClock.new()
	check(clock_copy.configure("world.test",WorldCore.tuning,0,JSON.parse_string(JSON.stringify(clock.snapshot()))) == OK and is_equal_approx(clock_copy.pending_seconds,clock.pending_seconds),"clock reload keeps pending world time")
	var first := WorldWeather.new()
	var second := WorldWeather.new()
	first.configure("world.test",424242,0,WorldCore.tuning)
	second.configure("world.test",424242,0,WorldCore.tuning)
	for tick: int in 1000: first.advance(1,tick+1)
	for tick: int in 500: second.advance(2,(tick+1)*2)
	check(first.state == second.state and first.rng.state == second.rng.state and is_equal_approx(first.remaining,second.remaining),"seed/catalog deterministic across timesteps")
	check(first.transition_sequence > 3,"weather transitions")
	var weather_copy := WorldWeather.new()
	check(weather_copy.configure("world.test",424242,1000,WorldCore.tuning,JSON.parse_string(JSON.stringify(first.snapshot()))) == OK,"weather reload")
	first.advance(1,1001)
	weather_copy.advance(1,1001)
	check(first.rng.state == weather_copy.rng.state and is_equal_approx(first.remaining,weather_copy.remaining),"exact RNG continuation after JSON reload")
	var bad := first.snapshot()
	bad.schema_version = 99
	check(weather_copy.configure("world.test",424242,1000,WorldCore.tuning,bad) == ERR_UNAVAILABLE,"future weather safe rejection")
	var runtime := SurfaceRuntime.new()
	var session := WorldSession.new()
	runtime.session = session
	session.water = WorldWater.new()
	var domain := WaterDomain.new()
	domain.set_process(false)
	domain.grid.tuning.tile_metres = 8
	domain.grid.tuning.cell_metres = 1
	domain.grid.height_sample = func(_point: Vector3) -> float: return 0.0
	domain.grid.initial_water = func(_point: Vector3) -> Dictionary: return {"kind":"lake","level":2}
	session.water.domain = domain
	var tile := domain.grid.ensure_tile(Vector2i.ZERO)
	tile.activity = WaterTile.Activity.SLEEPING
	var distant := domain.grid.ensure_tile(Vector2i(100,100))
	distant.activity = WaterTile.Activity.INACTIVE
	runtime.player = load("res://scenes/player/Player.tscn").instantiate()
	runtime.player.position = Vector3(2,0,2)
	add_child(runtime.player)
	runtime.player.set_physics_process(false)
	runtime.farms = FarmSystem.new(runtime.ledger)
	runtime.farms.till(Vector3(2,0,2),true,1)
	runtime.farms.till(Vector3(100,0,100),true,1)
	runtime.building = SupportGraph.new()
	runtime.containers = ContainerService.new()
	runtime.mobs = MobSimulation.new()
	runtime.mobs.domain = MobDomain.new(runtime.ledger,runtime.containers)
	runtime.core = WorldCore.new()
	runtime.core.runtime = runtime
	check(runtime.core.configure("world.rain",99,1200) == OK and runtime.core.clock.day == 3,"legacy world clock migration, no reset")
	runtime.core.weather.set_state("RAIN",1200)
	var volume := domain.grid.volume()
	runtime.core.advance(1)
	check(runtime.farms.plots["2,0,2"].moisture_deadline > runtime.ledger.clock and runtime.farms.plots["100,0,100"].moisture_deadline == 0,"rain waters nearby farm through public API")
	check(domain.grid.volume() > volume and runtime.core.last_rain.cells > 0 and tile.activity == WaterTile.Activity.ACTIVE,"rain adds bounded measured volume and wakes water")
	check(domain.grid.tiles.size() == 2 and distant.activity == WaterTile.Activity.INACTIVE,"rain does not allocate/simulate distant ocean")
	var strikes: Array = []
	runtime.core.weather.lightning_strike.connect(func(event: Dictionary) -> void: strikes.append(event))
	runtime.core.weather.set_state("THUNDERSTORM",runtime.ledger.clock)
	runtime.core.advance(20)
	check(strikes.size() == 1 and str(strikes[0].id).begins_with("world.rain:lightning:"),"semantic lightning event")
	var paused_volume := domain.grid.volume()
	runtime.core.clock.paused = true
	runtime.core.advance(30)
	check(domain.grid.volume() == paused_volume,"paused world has no rain contribution")
	runtime.core.clock.paused = false
	var inventory := InventoryState.new()
	inventory.add_item("bi.resource.meat",2,{"spoilage":{"remaining":12}})
	var active := InventorySimulation.new()
	active.register(inventory)
	runtime.core.clock.time_scale = 20
	runtime.core.advance(1)
	active.advance(1)
	check(is_equal_approx(StackPolicy.remaining(inventory._by_uid(inventory.slot_at(0).stack_uid).instance_data,ItemCatalog.resolve("bi.resource.meat"),active.clock.now),11),"spoilage remains active-time, independent of world scale")
	var storage := DirtyWorldStore.new("user://qa_world_core_c/"+Crypto.new().generate_random_bytes(8).hex_encode(),"world.rain")
	storage.load_world()
	storage.bind(runtime)
	var staged := storage.stage(DirtyWorldStore.global_state(runtime),{},0)
	check(staged.error == OK and storage.document.commit(staged.data) == OK,"WorldSave clock/weather atomic manifest")
	var reopened := DirtyWorldStore.new(storage.directory,"world.rain")
	check(reopened.load_world() == OK,"WorldSave reload")
	var surface := reopened.restore_surface()
	var reloaded := WorldCore.new()
	check(reloaded.configure("world.rain",99,0,surface.flags.world_core) == OK and reloaded.weather.rng.state == runtime.core.weather.rng.state and is_equal_approx(reloaded.clock.elapsed_game_seconds,runtime.core.clock.elapsed_game_seconds),"WorldSave owns weather and clock")
	check(SurfaceSaveValidator.validate(surface,inventory.snapshot()) == OK,"save validator accepts additive domains")
	check(not inventory.snapshot().has("weather") and not inventory.snapshot().has("world_clock"),"player inventory owns no world calendar")
	var baseline: Dictionary = {}
	for quality: String in ["Low","Medium","High"]:
		GameSettings.current = GameSettings.defaults()
		GameSettings.current.quality = quality
		var pure := WorldCore.new()
		pure.configure("same",44,0)
		for step: int in 500: pure.advance(.1)
		if baseline.is_empty(): baseline = pure.snapshot()
		else: check(AtomicDocument.same_value(baseline,pure.snapshot()),"quality leaves world authority identical")
	var foreign := WorldCore.new()
	check(foreign.configure("other.world",99,0,surface.flags.world_core) == ERR_INVALID_DATA,"world calendar cannot travel with a player")
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	session.add_child(sun)
	var sky := WorldEnvironment.new()
	sky.name = "Environment"
	sky.environment = Environment.new()
	session.add_child(sky)
	for quality: String in ["Low","Medium","High"]:
		GameSettings.current.quality = quality
		var presentation := WeatherPresentation.new()
		add_child(presentation)
		presentation.configure(runtime)
		check(presentation.rain.multimesh.instance_count == int(WorldCore.tuning.presentation[quality.to_lower()].rain_instances),"rain batch profile "+quality)
		presentation.free()
	var start := Time.get_ticks_usec()
	var benchmark := WorldCore.new()
	benchmark.configure("benchmark",11,0)
	for tick: int in 10000: benchmark.advance(.016)
	print("WORLD_CORE_C ","PASS" if failures == 0 else "FAIL"," assertions=",assertions," failures=",failures," pure10000_us=",Time.get_ticks_usec()-start," rain=",runtime.core.metrics," rain_result=",runtime.core.last_rain)
	active.free()
	runtime.player.free()
	runtime.mobs.free()
	domain.free()
	session.free()
	runtime.free()
	get_tree().quit(1 if failures else 0)
