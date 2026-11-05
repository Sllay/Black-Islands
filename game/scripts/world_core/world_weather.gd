class_name WorldWeather
extends RefCounted
## Seeded world state, never driven by particles or wall time.
signal weather_changed(id: String)
signal lightning_strike(event: Dictionary)
signal thunder(event: Dictionary)
var world_id := ""
var catalog_version := 1
var definitions: Array = []
var state := "CLEAR"
var remaining := 0.0
var thunder_remaining := 0.0
var transition_sequence := 0
var lightning_sequence := 0
var rng := RandomNumberGenerator.new()
var wind_direction := Vector2.RIGHT
var last_rain_metres := 0.0
var definition: Dictionary:
	get:
		for row: Dictionary in definitions:
			if row.id == state: return row
		return definitions[0]
func configure(identity: String, seed_value: int, elapsed: float, catalog: Dictionary, saved: Dictionary = {}) -> Error:
	world_id = identity
	catalog_version = int(catalog.catalog_version)
	definitions = catalog.weather.duplicate(true)
	rng.seed = (str(seed_value)+":"+str(catalog_version)+":"+str(floori(elapsed))+":weather").hash()
	set_state("CLEAR",elapsed)
	if saved.is_empty(): return OK
	if saved.get("schema_version") != 1 or saved.get("catalog_version") != catalog_version: return ERR_UNAVAILABLE
	if saved.get("world_id") != identity or saved.get("state") not in ["CLEAR","RAIN","THUNDERSTORM"]: return ERR_INVALID_DATA
	for key: String in ["remaining","thunder_remaining","transition_sequence","lightning_sequence"]:
		if not ContentValidator.numeric(saved.get(key),0,1.0e12): return ERR_INVALID_DATA
	for key: String in ["rng_seed","rng_state"]:
		if not saved.get(key) is String or not saved[key].is_valid_int(): return ERR_INVALID_DATA
	if not ContentValidator.vector2(saved.get("wind_direction")): return ERR_INVALID_DATA
	state = saved.state
	remaining = float(saved.remaining)
	thunder_remaining = float(saved.thunder_remaining)
	transition_sequence = int(saved.transition_sequence)
	lightning_sequence = int(saved.lightning_sequence)
	rng.seed = int(saved.rng_seed)
	rng.state = int(saved.rng_state)
	wind_direction = Vector2(saved.wind_direction[0],saved.wind_direction[1])
	return OK
func set_state(id: String, _world_seconds: float) -> Error:
	if id not in ["CLEAR","RAIN","THUNDERSTORM"]: return ERR_INVALID_PARAMETER
	state = id
	var row := definition
	remaining = rng.randf_range(float(row.duration_range[0]),float(row.duration_range[1]))
	thunder_remaining = 1.0/float(row.thunder_frequency) if float(row.thunder_frequency) > 0 else 0.0
	wind_direction = Vector2.RIGHT.rotated(rng.randf_range(-PI,PI))
	transition_sequence += 1
	weather_changed.emit(id)
	return OK
func advance(game_seconds: float, elapsed: float, observer: Vector3 = Vector3.ZERO) -> void:
	last_rain_metres = 0
	if game_seconds <= 0: return
	var left := game_seconds
	for segment: int in 2:
		if left <= 0: break
		var step := minf(left,remaining)
		last_rain_metres += float(definition.rain_intensity)*step
		left -= step
		remaining -= step
		if state == "THUNDERSTORM": _thunder_step(step,elapsed-left,observer)
		if remaining <= 0:
			var options: Array = definitions.filter(func(row: Dictionary) -> bool: return row.id != state)
			var total := 0.0
			for row: Dictionary in options: total += float(row.transition_weight)
			var choice := rng.randf()*total
			for row: Dictionary in options:
				choice -= float(row.transition_weight)
				if choice <= 0:
					set_state(row.id,elapsed-left)
					break
func _thunder_step(seconds: float, elapsed: float, observer: Vector3) -> void:
	thunder_remaining -= seconds
	for strike: int in 2:
		if thunder_remaining > 0: break
		thunder_remaining += 1.0/float(definition.thunder_frequency)
		lightning_sequence += 1
		var offset := Vector3(rng.randf_range(-24,24),0,rng.randf_range(-24,24))
		var point := observer+offset
		var event := {"id":world_id+":lightning:"+str(lightning_sequence),"world_id":world_id,"world_seconds":elapsed,"position":[point.x,point.y,point.z],"intensity":float(definition.rain_intensity)}
		lightning_strike.emit(event)
		thunder.emit(event)

func snapshot() -> Dictionary:
	return {"schema_version":1,"catalog_version":catalog_version,"world_id":world_id,"state":state,"remaining":remaining,"thunder_remaining":thunder_remaining,"transition_sequence":transition_sequence,"lightning_sequence":lightning_sequence,"rng_seed":str(rng.seed),"rng_state":str(rng.state),"wind_direction":[wind_direction.x,wind_direction.y]}
