@tool
class_name ContentData
extends RefCounted
## Shared serializable data boundary. No EditorPlugin or SceneTree dependency.
const FILES := {"items":"res://data/content/items.json","weapons":"res://data/content/weapons.json","effects":"res://data/content/effects.json","props":"res://data/content/props.json","recipes":"res://data/crafting/catalog.json"}
const GROUPS := {"items":"items","weapons":"weapons","visual_profiles":"weapons","movesets":"weapons","effects":"effects","props":"props","harvestables":"props","spawn_tables":"props","recipes":"recipes"}
static var revision := 0
static var _cache: Dictionary = {}
static func all() -> Dictionary:
	if _cache.is_empty():
		for key: String in FILES:
			var parser := JSON.new()
			if parser.parse(FileAccess.get_file_as_string(FILES[key])) == OK and parser.data is Dictionary:
				_cache[key] = parser.data
			else:
				_cache[key] = {"schema_version":-1}
	return _cache
static func rows(section: String) -> Array:
	return all().get(GROUPS.get(section,""),{}).get(section,[])
static func find(section: String, id: String) -> Dictionary:
	for row: Dictionary in rows(section):
		if row.get("id") == id:
			return row
	return {}
static func reload() -> void:
	_cache.clear()
	revision += 1
static func write_bundle(candidate: Dictionary, group: String) -> Error:
	if not FILES.has(group) or ContentValidator.has_errors(ContentValidator.validate(candidate)):
		return ERR_INVALID_DATA
	var path: String = FILES[group]
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string(JSON.stringify(candidate[group],"\t",false)+"\n")
	file.flush()
	var error := file.get_error()
	file.close()
	if error == OK:
		error = DirAccess.rename_absolute(path+".tmp",path)
	if error == OK:
		reload()
	return error
