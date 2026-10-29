extends SceneTree
## Authoring-only bake; no external filesystem dependency in an exported game.
func _initialize() -> void:
	var raw := FileAccess.get_file_as_string("res://../harness/lpc/catalog_v1.json")
	var data: Dictionary = JSON.parse_string(raw)
	var package := LPCCatalogPackage.new()
	package.catalog_json = raw
	for path: String in data.png_sources:
		var bytes := FileAccess.get_file_as_bytes("res://../harness/lpc/upstream_slice/" + path)
		var image := Image.new()
		assert(image.load_png_from_buffer(bytes) == OK, path)
		package.layer_bytes.append(bytes)
	DirAccess.make_dir_recursive_absolute("res://data/lpc")
	var error := ResourceSaver.save(package, "res://data/lpc/catalog_v1.res", ResourceSaver.FLAG_COMPRESS)
	assert(error == OK, error_string(error))
	print("LPC_BAKE PASS: ", package.layer_bytes.size(), " compressed PNG sources")
	quit()
