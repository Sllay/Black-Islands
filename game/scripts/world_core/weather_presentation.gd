class_name WeatherPresentation
extends Node3D
## Low-cost visual adapter; clocks, rain volume and weather transitions live elsewhere.
var runtime: SurfaceRuntime
var core: WorldCore
var rain: MultiMeshInstance3D
var material: ShaderMaterial
var sun: DirectionalLight3D
var environment: Environment
var flash: ColorRect
var flash_amount := 0.0
var _poll := 1.0
var _quality := ""
func configure(surface: SurfaceRuntime) -> void:
	runtime = surface
	core = runtime.core
	sun = runtime.session.get_node("Sun")
	var sky: WorldEnvironment = runtime.session.get_node("Environment")
	sky.environment = sky.environment.duplicate(true)
	environment = sky.environment
	rain = MultiMeshInstance3D.new()
	rain.name = "LocalRain"
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	material = ShaderMaterial.new()
	material.shader = load("res://shaders/weather_rain.gdshader")
	rain.material_override = material
	add_child(rain)
	var overlay := CanvasLayer.new()
	overlay.layer = 7
	add_child(overlay)
	flash = ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.color = Color(1,.94,.8,0)
	overlay.add_child(flash)
	core.weather.lightning_strike.connect(func(_event: Dictionary) -> void:
		flash_amount = float(_profile().flash))
	_refresh()
func _profile() -> Dictionary:
	var quality := str(GameSettings.current.get("quality","Medium")).to_lower()
	return WorldCore.tuning.presentation.get(quality,WorldCore.tuning.presentation.medium)
func _refresh() -> void:
	var profile := _profile()
	var count := int(profile.rain_instances)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(.025,.65)
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.use_custom_data = true
	instances.mesh = mesh
	instances.instance_count = count
	var rng := RandomNumberGenerator.new()
	rng.seed = 44004
	for index: int in count:
		instances.set_instance_transform(index,Transform3D(Basis.IDENTITY,Vector3(rng.randf_range(-9,9),rng.randf_range(0,9),rng.randf_range(-9,9))))
		instances.set_instance_custom_data(index,Color(rng.randf(),0,0,1))
	rain.multimesh = instances
	_quality = str(GameSettings.current.get("quality","Medium"))
func _process(delta: float) -> void:
	if core == null: return
	flash_amount = move_toward(flash_amount,0,delta*1.4)
	flash.color.a = flash_amount
	_poll += delta
	if _poll < .1: return
	_poll = 0
	if _quality != str(GameSettings.current.get("quality","Medium")): _refresh()
	var daylight := smoothstep(.0,.18,core.clock.time_of_day)*(1.0-smoothstep(.45,.65,core.clock.time_of_day))
	var storm := .62 if core.weather.state == "THUNDERSTORM" else (.82 if core.weather.state == "RAIN" else 1.0)
	sun.light_energy = (.08+1.22*daylight)*storm
	sun.light_color = Color("c4d8ef").lerp(Color("fff0ce"),daylight)
	environment.ambient_light_energy = (.18+.47*daylight)*storm
	environment.ambient_light_color = Color("718bb7").lerp(Color("d2e6ee"),daylight)
	environment.background_color = Color("15233b").lerp(Color("79b7cb"),daylight)*Color(storm,storm,storm,1)
	rain.global_position = runtime.player.global_position+Vector3.UP*5
	rain.visible = core.weather.state != "CLEAR"
	material.set_shader_parameter("strength",.8 if core.weather.state == "RAIN" else 1.0)
	var wind := core.weather.wind_direction*float(core.weather.definition.wind_intensity)
	material.set_shader_parameter("wind",wind)
	runtime.session.water.wind_direction = core.weather.wind_direction
	runtime.session.water.wind_intensity = float(core.weather.definition.wind_intensity)
	for water: WaterRenderer in get_tree().get_nodes_in_group("water_renderers"):
		water.set_weather_wind(float(core.weather.definition.wind_intensity))
	if runtime.foliage != null and runtime.foliage.native_foliage != null:
		runtime.foliage.native_foliage.set_weather_wind(wind)
