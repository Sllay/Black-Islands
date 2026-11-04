class_name WeaponCatalog
extends RefCounted
static var _weapons: Dictionary = {}
static var _visuals: Dictionary = {}
static var _revision := -1
static func _refresh() -> void:
	if _revision == ContentData.revision: return
	_weapons.clear()
	_visuals.clear()
	for row: Dictionary in ContentData.rows("weapons"): _weapons[row.id] = WeaponDefinition.new(row)
	for row: Dictionary in ContentData.rows("visual_profiles"): _visuals[row.id] = WeaponVisualProfile.new(row)
	_revision = ContentData.revision
static func resolve(id: String) -> WeaponDefinition:
	_refresh()
	return _weapons.get(id)
static func visual(id: String) -> WeaponVisualProfile:
	_refresh()
	return _visuals.get(id)
static func for_item(definition: ItemDefinition) -> WeaponDefinition:
	return resolve(definition.module("WeaponModule").get("weapon_id","")) if definition != null else null
