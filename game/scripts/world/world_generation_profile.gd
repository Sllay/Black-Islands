class_name WorldGenerationProfile
extends RefCounted
## Immutable generation contract; schema2 saves retain explicit generator identity.
const VERSION := 2
const ID := "chapter1_native_960m_v2"
static var _chapter1: Dictionary = {}

static func chapter1() -> Dictionary:
	if _chapter1.is_empty():
		_chapter1 = JSON.parse_string(FileAccess.get_file_as_string("res://data/world/chapter1_v2.json"))
	return _chapter1.duplicate(true)

static func supported(version: int, profile: String) -> bool:
	return (version == 1 and profile == IslandField.PROFILE_ID) or (version == VERSION and profile == ID)

static func field(seed_value: int, version: int, profile: String) -> IslandField:
	if not supported(version,profile):
		return null
	return WorldFieldV2.new(seed_value) if version == VERSION else IslandField.new(seed_value)
