class_name SchemaMigrations
extends RefCounted
## Explicit ordered N -> N+1 registry. Future schema never downgraded/recovered.
static func read(document: AtomicDocument, steps: Dictionary) -> Error:
	if not FileAccess.file_exists(document.path):
		return document.read()
	var header: Variant = JSON.parse_string(FileAccess.get_file_as_string(document.path))
	if not header is Dictionary:
		return document.read()
	var version := int(header.get("schema",0))
	if version > document.schema:
		return ERR_UNAVAILABLE
	if version == document.schema:
		return document.read()
	var prior := AtomicDocument.new(document.path,version,document.identity)
	var error := prior.read()
	if error != OK:
		return error
	var data := prior.loaded.duplicate(true)
	while version < document.schema:
		if not steps.has(version):
			return ERR_UNAVAILABLE
		var result: Dictionary = steps[version].call(data)
		if result.get("error",ERR_INVALID_DATA) != OK:
			return result.get("error",ERR_INVALID_DATA)
		data = result.data
		version += 1
	var archive := document.path+".schema%d"%int(header.schema)
	if not FileAccess.file_exists(archive):
		error = DirAccess.copy_absolute(document.path,archive)
		if error != OK:
			return error
	document.revision = prior.revision
	return document.commit(data)

static func player_1_to_2(data: Dictionary) -> Dictionary:
	if not data.get("character") is Dictionary or not data.get("player_id") is String:
		return {"error":ERR_INVALID_DATA}
	var result := data.duplicate(true)
	var character: Dictionary = result.character
	character.erase("spawn")
	character.erase("surface")
	character.stats.merge({"mana":100.0,"max_mana":100.0},false)
	result.cosmetics = character.appearance.duplicate(true)
	result.unlocks = result.get("unlocks",{"skills":[],"recipes":[]})
	result.unlocks.starter_tools = true # C01 records only persisted after kit provisioning.
	return {"error":OK,"data":result}
