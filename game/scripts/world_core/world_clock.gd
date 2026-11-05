class_name WorldClock
extends RefCounted
## Calendar authority. Active seconds are input; no wall clock or offline catch-up.
signal time_changed(elapsed: float, day: int, time_of_day: float)
signal day_started(day: int)
signal day_ended(day: int)
signal time_period_changed(period: String)
var world_id := ""
var elapsed_game_seconds := 0.0
var time_scale := 1.0
var paused := false
var day_seconds := 600.0
var pending_seconds := 0.0
var max_step := 30.0
var event_interval := 1.0
var _last_event := 0.0
var day: int:
	get: return floori(elapsed_game_seconds/day_seconds)+1
var time_of_day: float:
	get: return fposmod(elapsed_game_seconds,day_seconds)/day_seconds
var period: String:
	get:
		var phase := time_of_day
		return "DAWN" if phase < .1 else ("DAY" if phase < .5 else ("DUSK" if phase < .6 else "NIGHT"))
func configure(identity: String, defaults: Dictionary, legacy_seconds: float = 0.0, saved: Dictionary = {}) -> Error:
	world_id = identity
	day_seconds = float(defaults.day_seconds)
	max_step = float(defaults.max_clock_step)
	event_interval = float(defaults.time_event_seconds)
	time_scale = float(defaults.default_time_scale)
	elapsed_game_seconds = maxf(0,legacy_seconds)
	if not saved.is_empty():
		if saved.get("schema_version") != 1: return ERR_UNAVAILABLE
		if saved.get("world_id") != identity: return ERR_INVALID_DATA
		for key: String in ["elapsed_game_seconds","pending_seconds","time_scale","day_seconds"]:
			if not ContentValidator.numeric(saved.get(key),0,1.0e12): return ERR_INVALID_DATA
		if saved.day_seconds < 60 or saved.day_seconds > 86400 or saved.time_scale > 60 or not saved.get("paused") is bool: return ERR_INVALID_DATA
		elapsed_game_seconds = float(saved.elapsed_game_seconds)
		pending_seconds = float(saved.pending_seconds)
		time_scale = float(saved.time_scale)
		day_seconds = float(saved.day_seconds)
		paused = saved.paused
	_last_event = elapsed_game_seconds
	return OK
func advance(active_seconds: float) -> float:
	if paused or time_scale <= 0 or not is_finite(active_seconds) or active_seconds < 0: return 0
	pending_seconds += active_seconds*clampf(time_scale,0,60)
	var step := minf(pending_seconds,minf(max_step,day_seconds*.05))
	var old_day := day
	var old_period := period
	elapsed_game_seconds += step
	pending_seconds -= step
	if day != old_day:
		day_ended.emit(old_day)
		day_started.emit(day)
	if period != old_period: time_period_changed.emit(period)
	if elapsed_game_seconds-_last_event >= event_interval:
		_last_event = elapsed_game_seconds
		time_changed.emit(elapsed_game_seconds,day,time_of_day)
	return step
func snapshot() -> Dictionary:
	return {"schema_version":1,"world_id":world_id,"elapsed_game_seconds":elapsed_game_seconds,"pending_seconds":pending_seconds,"time_scale":time_scale,"day_seconds":day_seconds,"paused":paused}
