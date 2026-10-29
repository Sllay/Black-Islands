class_name LPCCatalog
extends RefCounted

static var _package: LPCCatalogPackage
static var _data: Dictionary = {}
static var _assets: Dictionary = {}

static func data() -> Dictionary:
	if _data.is_empty():
		_package = load("res://data/lpc/catalog_v1.res") as LPCCatalogPackage
		assert(_package != null, "Bake the pinned LPC slice with scripts/lpc/bake_slice.sh")
		_data = JSON.parse_string(_package.catalog_json)
		for entry: Dictionary in _data.assets:
			_assets[entry.id] = entry
	return _data

static func asset(id: String) -> Dictionary:
	data()
	return _assets.get(id, {})

static func source_image(index: int) -> Image:
	data()
	var image := Image.new()
	if index < 0 or index >= _package.layer_bytes.size() or image.load_png_from_buffer(_package.layer_bytes[index]) != OK:
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image

static func default_appearance() -> Dictionary:
	return {"schema_version":1, "catalog_version":data().catalog_version, "body_type":"male",
		"selections":{"body":"lpc.body.human_male", "head":"lpc.head.human_male", "hair":"lpc.hair.plain",
			"torso":"lpc.clothes.longsleeve", "legs":"lpc.legs.pants"},
		"palettes":{"body":"skin.light", "head":"skin.light", "hair":"hair.chestnut",
			"torso":"cloth.bluegray", "legs":"cloth.brown"}, "equipment_visuals":[]}

static func normalize(config: Dictionary) -> Dictionary:
	if config.get("schema_version") != 1 or config.get("catalog_version") != data().catalog_version or config.get("body_type") not in ["male","female"]:
		return {}
	if not config.get("selections") is Dictionary or not config.get("palettes") is Dictionary or not config.get("equipment_visuals",[]) is Array:
		return {}
	var result := {"schema_version":1,"catalog_version":data().catalog_version,"body_type":config.body_type,"selections":{},"palettes":{},"equipment_visuals":[]}
	for role: String in ["body","head","torso","legs"]:
		if not config.selections.has(role):
			return {}
	for role: String in config.selections:
		var id := str(config.selections[role])
		var entry := asset(id)
		if entry.is_empty() or entry.role != role or config.body_type not in entry.body_types or entry.legal_status != "accepted":
			return {}
		if config.palettes.get(role) != entry.palette:
			return {}
		if entry.get("match_body_color",false) and config.palettes.get("body") != entry.palette:
			return {}
		result.selections[role] = id
		result.palettes[role] = entry.palette
	for id: Variant in config.get("equipment_visuals",[]):
		if not id is String or asset(id).get("role") != "weapon":
			return {}
		if id not in result.equipment_visuals:
			result.equipment_visuals.append(id)
	result.equipment_visuals.sort()
	return result

static func appearance_key(config: Dictionary) -> String:
	var normalized := normalize(config)
	return JSON.stringify(normalized, "", true).sha256_text() if not normalized.is_empty() else ""
