class_name FrontendLibrary
extends RefCounted
## Five world slots and five globally portable characters. No seed in player ID.
const CAPACITY := 5
var directory: String

func _init(root: String = "user://rc0") -> void:
	directory = root

func document(kind: String, slot: int) -> AtomicDocument:
	return AtomicDocument.new(directory.path_join("%s_%02d.json"%[kind,slot]),1,{"kind":kind,"slot":slot})

func summaries(kind: String) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for slot: int in range(1,CAPACITY+1):
		var doc := document(kind,slot)
		var error := doc.read()
		rows.append({"slot":slot,"state":"unavailable" if error != OK else ("empty" if doc.loaded.is_empty() else "ready"),"data":doc.loaded})
	return rows

func read(kind: String, slot: int) -> Dictionary:
	if slot < 1 or slot > CAPACITY:
		return {}
	var doc := document(kind,slot)
	return doc.loaded if doc.read() == OK else {}

func create_world(slot: int, title: String, seed_value: int) -> Error:
	if slot < 1 or slot > CAPACITY or title.strip_edges().is_empty() or title.length() > 48:
		return ERR_INVALID_PARAMETER
	var doc := document("world",slot)
	if doc.read() != OK or not doc.loaded.is_empty():
		return ERR_ALREADY_IN_USE
	var id := Crypto.new().generate_random_bytes(16).hex_encode()
	return doc.commit({"world_id":id,"save_id":id,"display_name":title.strip_edges(),"world_seed":seed_value,
		"world_generation_version":IslandField.VERSION,"world_profile":IslandField.PROFILE_ID,"difficulty":"Normal",
		"created_at":Time.get_datetime_string_from_system(true)+"Z","played_seconds":0.0,"world_clock":0.0,"generated":false})

func edit_world(slot: int, title: String, seed_value: int) -> Error:
	var doc := document("world",slot)
	if doc.read() != OK or doc.loaded.is_empty() or title.strip_edges().is_empty() or title.length() > 48:
		return ERR_INVALID_DATA
	if doc.loaded.generated and seed_value != int(doc.loaded.world_seed):
		return ERR_UNAUTHORIZED
	doc.loaded.display_name = title.strip_edges()
	doc.loaded.world_seed = seed_value
	return doc.commit(doc.loaded)

func create_player(slot: int, title: String, appearance: Dictionary) -> Error:
	if slot < 1 or slot > CAPACITY or title.strip_edges().is_empty() or title.length() > 32 or LPCCatalog.normalize(appearance).is_empty():
		return ERR_INVALID_PARAMETER
	var doc := document("player",slot)
	if doc.read() != OK or not doc.loaded.is_empty():
		return ERR_ALREADY_IN_USE
	return doc.commit({"player_id":Crypto.new().generate_random_bytes(16).hex_encode(),"name":title.strip_edges(),
		"appearance":LPCCatalog.normalize(appearance),"level":1,"played_seconds":0.0,
		"created_at":Time.get_datetime_string_from_system(true)+"Z"})

func edit_player(slot: int, appearance: Dictionary) -> Error:
	var doc := document("player",slot)
	if doc.read() != OK or doc.loaded.is_empty() or LPCCatalog.normalize(appearance).is_empty():
		return ERR_INVALID_DATA
	var prior: Dictionary = doc.loaded.appearance
	if appearance.body_type != prior.body_type:
		return ERR_UNAUTHORIZED
	for role: String in LPCCustomization.immutable_roles():
		if appearance.selections.get(role,"") != prior.selections.get(role,""):
			return ERR_UNAUTHORIZED
	doc.loaded.appearance = LPCCatalog.normalize(appearance)
	return doc.commit(doc.loaded)

func trash(kind: String, slot: int) -> Error:
	var doc := document(kind,slot)
	if doc.read() != OK or doc.loaded.is_empty():
		return ERR_INVALID_DATA
	var id: String = doc.loaded.get("world_id",doc.loaded.get("player_id",""))
	var target := directory.path_join("trash/"+kind+"_"+id)
	var error := DirAccess.make_dir_recursive_absolute(target)
	if error != OK:
		return error
	# Archive metadata first; old state is recoverable and never crosses owners.
	error = DirAccess.rename_absolute(doc.path,target.path_join("metadata.json"))
	if error != OK:
		return error
	for suffix: String in [".bak",".tmp"]:
		if FileAccess.file_exists(doc.path+suffix):
			DirAccess.rename_absolute(doc.path+suffix,target.path_join("metadata.json"+suffix))
	return OK

func world_directory(world: Dictionary) -> String:
	return directory.path_join("worlds/"+str(world.world_id))

func player_directory(player: Dictionary) -> String:
	return directory.path_join("players/"+str(player.player_id))
