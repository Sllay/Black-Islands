class_name GameSettings
extends RefCounted
## Staged settings; a single confirmed commit applies runtime-safe values.
static var current: Dictionary = {}
static var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/graphics_profiles.json"))
static var path := "user://rc0/settings.json"
static var apply_count := 0

static func defaults() -> Dictionary:
	return {"audio":{"Music":80,"Audio":80,"Voice":80},"quality":"Medium","distance":6,
		"shadows":true,"vsync":true,"backend":"mobile" if OS.has_feature("mobile") else "desktop_forward_plus",
		"overrides":{"distance":false,"shadows":false,"vsync":false}}

static func load_settings() -> Error:
	var doc := AtomicDocument.new(path,1,{"kind":"settings"})
	var error := doc.read()
	current = defaults()
	if error != OK:
		return error
	if not doc.loaded.is_empty() and valid(doc.loaded):
		current = GraphicsBudget.migrate_settings(doc.loaded)
	apply_safe()
	return OK

static func valid(data: Dictionary) -> bool:
	if data.has("overrides"):
		if not data.overrides is Dictionary:
			return false
		for key: String in ["distance","shadows","vsync"]:
			if not data.overrides.get(key) is bool:
				return false
	if data.get("quality") not in catalog.presets or data.get("backend") not in catalog.backends or not data.get("audio") is Dictionary:
		return false
	if int(data.get("distance",0)) not in range(2,11) or data.distance != int(data.distance) or not data.get("shadows") is bool or not data.get("vsync") is bool:
		return false
	for bus: String in ["Music","Audio","Voice"]:
		var value: Variant = data.audio.get(bus)
		if not (value is float or value is int) or value < 0 or value > 100 or value != int(value):
			return false
	return true

static func save(staged: Dictionary) -> Error:
	if not valid(staged):
		return ERR_INVALID_DATA
	var doc := AtomicDocument.new(path,1,{"kind":"settings"})
	var error := doc.read()
	if error != OK:
		return error
	error = doc.commit(staged)
	if error == OK:
		var startup := ConfigFile.new()
		var method: String = catalog.backends[staged.backend]
		startup.set_value("rendering","renderer/rendering_method",method)
		startup.set_value("rendering","renderer/rendering_method.mobile",method)
		error = startup.save(path.get_base_dir().path_join("renderer_override.cfg"))
		if error != OK:
			return error
		current = GraphicsBudget.migrate_settings(staged)
		apply_safe()
	return error

static func apply_safe() -> void:
	apply_count += 1
	for bus: String in ["Music","Audio","Voice"]:
		var index := AudioServer.get_bus_index(bus)
		if index < 0:
			AudioServer.add_bus()
			index = AudioServer.bus_count-1
			AudioServer.set_bus_name(index,bus)
		AudioServer.set_bus_send(index,"Master")
		var volume := int(current.audio[bus])
		AudioServer.set_bus_mute(index,volume == 0)
		AudioServer.set_bus_volume_db(index,linear_to_db(volume/100.0) if volume > 0 else -80.0)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if current.vsync else DisplayServer.VSYNC_DISABLED)
	if Engine.get_main_loop() is SceneTree:
		apply_scene((Engine.get_main_loop() as SceneTree).root)

static func apply_scene(root: Node) -> void:
	var budget := effective()
	RenderingServer.directional_shadow_atlas_set_size(int(budget.shadow_atlas_size),true)
	RenderingServer.directional_soft_shadow_filter_set_quality(int(budget.shadow_filter))
	for light: Node in root.find_children("*","DirectionalLight3D",true,false):
		light.shadow_enabled = budget.shadows
		light.directional_shadow_max_distance = float(budget.shadow_distance)
	for session: Node in root.find_children("*","Node3D",true,false):
		if session is WorldSession and session.terrain != null:
			session.apply_graphics(budget)
	for foliage: Node in root.find_children("*","Node3D",true,false):
		if foliage is WaterRenderer:
			foliage.apply_profile(budget)
		if foliage is FoliagePresenter:
			foliage.apply_profile(budget)

static func distance_budget(level: int) -> Dictionary:
	return catalog.distance_levels[str(clampi(level,2,10))].duplicate(true)

static func effective() -> Dictionary:
	return GraphicsBudget.resolve(current if not current.is_empty() else defaults(),catalog)

static func staged_copy() -> Dictionary:
	var result := GraphicsBudget.migrate_settings(current if not current.is_empty() else defaults())
	var resolved := GraphicsBudget.resolve(result,catalog)
	result.distance = resolved.distance_level
	result.shadows = resolved.shadows
	return result
