class_name LPCCompositionCache
extends RefCounted
## Bounded appearance cache. No composition/upload on animation ticks.
const CAPACITY := 4
static var compositions := 0
static var texture_creations := 0
static var cache_hits := 0
static var _cache: Dictionary = {}
static var _order: Array[String] = []

static func obtain(config: Dictionary) -> LPCAppearance:
	var normalized := LPCCatalog.normalize(config)
	if normalized.is_empty():
		normalized = LPCCatalog.default_appearance()
	var key := LPCCatalog.appearance_key(normalized)
	if _cache.has(key):
		cache_hits += 1
		_order.erase(key)
		_order.append(key)
		return _cache[key]
	var appearance := _compose(normalized, key)
	if appearance == null:
		return null
	if _order.size() >= CAPACITY:
		_cache.erase(_order.pop_front())
	_cache[key] = appearance
	_order.append(key)
	compositions += 1
	return appearance

static func _compose(config: Dictionary, key: String) -> LPCAppearance:
	var catalog := LPCCatalog.data()
	var layers: Array[Dictionary] = []
	var ids: Array = config.selections.values()
	ids.append_array(config.equipment_visuals)
	var images: Dictionary = {}
	for id: String in ids:
		var entry := LPCCatalog.asset(id)
		for row: Dictionary in entry.layers:
			var layer := row.duplicate()
			layer.weapon = entry.role == "weapon"
			layers.append(layer)
			var index := int(row.source_index)
			if not images.has(index):
				images[index] = LPCCatalog.source_image(index)
				if images[index] == null:
					return null
	layers.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.z < b.z)
	var result := LPCAppearance.new()
	result.key = key
	result.config = config.duplicate(true)
	for action: String in ["MOVE", "MELEE_SLASH"]:
		var frame_size := 64
		for layer: Dictionary in layers:
			if layer.custom_action == action:
				frame_size = maxi(frame_size, int(layer.frame_size))
		var clip: Dictionary = catalog.clips[action]
		var frames := int(clip.frames)
		var atlas := Image.create_empty(frame_size * frames, frame_size * 4, false, Image.FORMAT_RGBA8)
		for direction: int in range(4):
			for frame: int in range(frames):
				for layer: Dictionary in layers:
					if not layer.custom_action.is_empty() and layer.custom_action != action:
						continue
					if layer.weapon and action == "MELEE_SLASH" and layer.custom_action.is_empty():
						continue # Custom attack replaces, rather than duplicates, held weapon.
					var size := int(layer.frame_size)
					var row := direction if not layer.custom_action.is_empty() else int(catalog.clip_rows[action][direction])
					var source := Rect2i(frame * size, row * size, size, size)
					var inset := int((frame_size - size) * 0.5)
					atlas.blend_rect(images[int(layer.source_index)], source,
						Vector2i(frame * frame_size + inset, direction * frame_size + inset))
		var texture := ImageTexture.create_from_image(atlas)
		texture_creations += 1
		result.clips[action] = {"texture":texture, "frames":frames, "fps":float(clip.fps),
			"loop":clip.loop, "frame_size":frame_size, "pivot":foot_pivot(frame_size)}
	return result

static func foot_pivot(frame_size: int) -> Vector2:
	return Vector2(frame_size * 0.5, frame_size * 0.5 + 28.0)

static func report() -> Dictionary:
	return {"compositions":compositions, "textures":texture_creations, "cache_hits":cache_hits,
		"cached_appearances":_cache.size()}
