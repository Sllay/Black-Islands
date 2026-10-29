class_name PortablePlayerStore
extends PlayerSaveStore
## Compatibility adapter for the P03 actor API. Durable identity is player-only.
var document: AtomicDocument
var profile: Dictionary
var unlocks := {"skills":[],"recipes":[]}

func _init(storage_directory: String, owner: Dictionary) -> void:
	super(storage_directory,{"save_id":owner.player_id,"world_seed":0,"world_generation_version":1,
		"world_profile":"portable_player","created_at":owner.created_at})
	profile = owner
	identity = {"player_id":owner.player_id}
	document = AtomicDocument.new(directory.path_join("profile.json"),2,identity)

func load_player() -> Error:
	var error := SchemaMigrations.read(document,{1:SchemaMigrations.player_1_to_2})
	if error != OK:
		return error
	if not document.loaded.is_empty() and not document.loaded.get("character") is Dictionary:
		return ERR_FILE_CORRUPT
	revision = document.revision
	loaded = bridge(document.loaded)
	unlocks = document.loaded.get("unlocks",unlocks).duplicate(true)
	if not document.loaded.is_empty():
		if document.loaded.get("player_id") != profile.player_id or PlayerSaveStore.validate_snapshot(loaded) != OK:
			return ERR_INVALID_DATA
	return OK

func bridge(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}
	var result: Dictionary = data.character.duplicate(true)
	# Spawn is session-owned; this neutral adapter value is never written to player.
	result.schema_version = 1
	result.spawn = {"context":"surface","feet":[0,12,0],"facing":[0,0,-1]}
	return result

func payload(snapshot: Dictionary, played: float) -> Dictionary:
	var character := snapshot.duplicate(true)
	character.erase("spawn")
	character.erase("surface")
	character.erase("schema_version")
	character.stats.merge({"mana":100.0,"max_mana":100.0},false)
	return {"player_id":profile.player_id,"name":profile.name,"level":profile.level,
		"played_seconds":played,"character":character,"cosmetics":character.appearance.duplicate(true),
		"unlocks":unlocks.duplicate(true)}

func commit(snapshot: Dictionary) -> Error:
	var error := document.commit(payload(snapshot,float(document.loaded.get("played_seconds",0))))
	if error == OK:
		loaded = snapshot.duplicate(true)
		revision = document.revision
	return error
