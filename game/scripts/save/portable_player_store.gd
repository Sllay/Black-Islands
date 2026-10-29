class_name PortablePlayerStore
extends PlayerSaveStore
## Compatibility adapter for the P03 actor API. Durable identity is player-only.
var document: AtomicDocument
var profile: Dictionary

func _init(storage_directory: String, owner: Dictionary) -> void:
	super(storage_directory,{"save_id":owner.player_id,"world_seed":0,"world_generation_version":1,
		"world_profile":"portable_player","created_at":owner.created_at})
	profile = owner
	document = AtomicDocument.new(directory.path_join("profile.json"),1,{"player_id":owner.player_id})

func load_player() -> Error:
	var error := document.read()
	if error != OK:
		return error
	revision = document.revision
	loaded = bridge(document.loaded)
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
	return {"player_id":profile.player_id,"name":profile.name,"level":profile.level,
		"played_seconds":played,"character":character}

func commit(snapshot: Dictionary) -> Error:
	var error := document.commit(payload(snapshot,float(document.loaded.get("played_seconds",0))))
	if error == OK:
		loaded = snapshot.duplicate(true)
		revision = document.revision
	return error
