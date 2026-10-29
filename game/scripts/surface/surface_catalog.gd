class_name SurfaceCatalog
extends RefCounted
const VERSION := 1
static var _data: Dictionary = {}
static func data() -> Dictionary:
	if _data.is_empty():
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/surface/catalog.json"))
	return _data
