class_name GraphicsBudget
extends RefCounted
## Immutable catalog profiles plus explicit user overrides. Backend is startup-only.
static func resolve(settings: Dictionary, catalog: Dictionary) -> Dictionary:
	var profile: Dictionary = catalog.presets[settings.get("quality","Medium")].duplicate(true)
	var overrides: Dictionary = settings.get("overrides",{"distance":true,"shadows":true,"vsync":true})
	var level := int(settings.get("distance",6)) if overrides.get("distance",false) else int(profile.default_distance)
	var distance: Dictionary = catalog.distance_levels[str(clampi(level,2,10))]
	profile.distance_level = level
	profile.viewer_metres = float(distance.viewer_metres)*float(profile.terrain_view_scale)
	profile.near_ring = int(distance.near_ring)
	profile.prop_distance = minf(float(profile.prop_distance),float(distance.prop_metres)*1.5)
	profile.foliage.near *= float(distance.foliage_range_scale)
	profile.foliage.far = minf(56,float(profile.foliage.far)*float(distance.foliage_range_scale))
	profile.shadows = bool(settings.get("shadows",true)) if overrides.get("shadows",false) else bool(profile.shadows)
	profile.vsync = bool(settings.get("vsync",true))
	profile.quality = settings.get("quality","Medium")
	profile.backend = settings.get("backend","compatibility")
	return profile
static func migrate_settings(data: Dictionary) -> Dictionary:
	var result := data.duplicate(true)
	if not result.has("overrides"):
		# R1 saves explicitly exposed all three controls. Preserve their choices.
		result.overrides = {"distance":true,"shadows":true,"vsync":true}
	return result
