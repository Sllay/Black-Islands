class_name SurfaceCatalog
extends RefCounted
const VERSION := 1
static var _data: Dictionary = {}
static var _revision := -1
static func data() -> Dictionary:
	if _data.is_empty() or _revision != ContentData.revision:
		_data = JSON.parse_string(FileAccess.get_file_as_string("res://data/surface/catalog.json"))
		for row: Dictionary in ContentData.rows("props"): _data.props.append(row)
		for row: Dictionary in ContentData.rows("harvestables"): _data.harvestables[row.id] = row
		_revision = ContentData.revision
	return _data
