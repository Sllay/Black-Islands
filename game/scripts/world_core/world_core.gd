class_name WorldCore
extends RefCounted
## World-only composition. GameplayTimeSource/spoilage remains independent.
static var tuning: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_core/time_weather.json"))
var clock := WorldClock.new()
var weather := WorldWeather.new()
var runtime: SurfaceRuntime
var rain_debt := 0.0
var rain_elapsed := 0.0
var last_rain := {"cells":0,"metres":0.0,"farms":0}
var metrics := {"clock_us":0,"weather_us":0,"rain_us":0,"rain_pulses":0}
func configure(identity: String, seed_value: int, legacy_seconds: float, saved: Dictionary = {}) -> Error:
	if not saved.is_empty() and saved.get("schema_version") != 1: return ERR_UNAVAILABLE
	if not saved.is_empty() and (not saved.get("clock") is Dictionary or not saved.get("weather") is Dictionary or saved.clock.is_empty() or saved.weather.is_empty()): return ERR_INVALID_DATA
	var error := clock.configure(identity,tuning,legacy_seconds,saved.get("clock",{}))
	if error != OK: return error
	clock.max_step = minf(clock.max_step,30)
	error = weather.configure(identity,seed_value,clock.elapsed_game_seconds,tuning,saved.get("weather",{}))
	if error != OK: return error
	if not ContentValidator.numeric(saved.get("rain_debt",0),0,100) or not ContentValidator.numeric(saved.get("rain_elapsed",0),0,1e12): return ERR_INVALID_DATA
	rain_debt = float(saved.get("rain_debt",0))
	rain_elapsed = float(saved.get("rain_elapsed",0))
	return OK
func advance(active_seconds: float) -> void:
	if clock.paused or clock.time_scale <= 0: return
	var start := Time.get_ticks_usec()
	var seconds := clock.advance(active_seconds)
	metrics.clock_us = Time.get_ticks_usec()-start
	var position := runtime.player.global_position if runtime != null and runtime.player != null else Vector3.ZERO
	start = Time.get_ticks_usec()
	weather.advance(seconds,clock.elapsed_game_seconds,position)
	metrics.weather_us = Time.get_ticks_usec()-start
	if runtime != null:
		runtime.ledger.clock = clock.elapsed_game_seconds
		runtime.ledger.day_seconds = clock.day_seconds
	rain_debt += weather.last_rain_metres
	if seconds > 0 and rain_debt > 0: rain_elapsed += active_seconds
	elif rain_debt <= 0: rain_elapsed = 0
	if rain_elapsed >= float(tuning.rain_pulse_seconds) and rain_debt > 0 and runtime != null:
		rain_elapsed -= float(tuning.rain_pulse_seconds)
		var metres := minf(rain_debt,float(tuning.rain_max_metres_per_pulse))
		rain_debt -= metres
		start = Time.get_ticks_usec()
		var radius := float(tuning.rain_radius)
		var area := AABB(position-Vector3(radius,128,radius),Vector3(radius*2,256,radius*2))
		var cells := runtime.session.water.add_precipitation(area,metres,int(tuning.rain_cell_budget)) if runtime.session != null and runtime.session.water != null else 0
		var farms := runtime.farms.rain(area,weather.state == "THUNDERSTORM")
		last_rain = {"cells":cells,"metres":metres,"farms":farms}
		metrics.rain_us = Time.get_ticks_usec()-start
		metrics.rain_pulses += 1
	checkpoint()
func checkpoint() -> void:
	if runtime != null: runtime.ledger.flags.world_core = snapshot()
func snapshot() -> Dictionary:
	return {"schema_version":1,"clock":clock.snapshot(),"weather":weather.snapshot(),"rain_debt":rain_debt,"rain_elapsed":rain_elapsed}
