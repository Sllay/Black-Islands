class_name LegacySaveImport
extends RefCounted
## Non-destructive P04 dev importer. Originals and incompatible 1m pieces archived.
static func run(library: FrontendLibrary, source_profiles: String = "user://profiles", source_worlds: String = "user://worlds") -> Dictionary:
	var report := {"imported":0,"quarantined_pieces":0,"errors":[]}
	var journal := library.directory.path_join("pending_legacy.json")
	var recovery := AtomicBatch.recover(journal)
	if recovery != OK:
		report.errors.append(recovery)
		return report
	var source := SlotStore.new(source_profiles)
	for slot_id: String in SlotStore.SLOT_IDS:
		var old := source.read_slot(slot_id)
		if old.state != "ready":
			continue
		var metadata: Dictionary = old.metadata
		if not FileAccess.file_exists(source_worlds.path_join(str(metadata.get("save_id",""))).path_join("player.json")):
			continue
		if not metadata.has("world_seed") or _already_imported(library,metadata.save_id):
			continue
		var world_slot := _free(library,"world")
		var player_slot := _free(library,"player")
		if world_slot == 0 or player_slot == 0:
			report.errors.append("No free frontend slots; original dev saves retained")
			break
		var result := _one(library,metadata,source_worlds.path_join(metadata.save_id),world_slot,player_slot,journal)
		if result.error != OK:
			report.errors.append({"slot":slot_id,"error":result.error})
		else:
			report.imported += 1
			report.quarantined_pieces += result.quarantined
	return report

static func _free(library: FrontendLibrary, kind: String) -> int:
	for row: Dictionary in library.summaries(kind):
		if row.state == "empty":
			return row.slot
	return 0

static func _already_imported(library: FrontendLibrary, id: String) -> bool:
	for row: Dictionary in library.summaries("world"):
		if row.data.get("world_id","") == id or row.data.get("legacy_source","") == id:
			return true
	return false

static func _one(library: FrontendLibrary, metadata: Dictionary, source: String, world_slot: int, player_slot: int, journal: String) -> Dictionary:
	var envelope: Variant = JSON.parse_string(FileAccess.get_file_as_string(source.path_join("player.json")))
	if not envelope is Dictionary or envelope.get("save_schema_version") != 1:
		return {"error":ERR_UNAVAILABLE}
	if not envelope.get("payload") is String or envelope.get("sha256") != envelope.payload.sha256_text():
		return {"error":ERR_FILE_CORRUPT}
	for key: String in ["save_id","world_seed","world_profile","world_generation_version"]:
		if envelope.get("identity",{}).get(key) != metadata.get(key):
			return {"error":ERR_FILE_CORRUPT}
	var snapshot: Dictionary = JSON.parse_string(envelope.payload)
	var surface: Dictionary = snapshot.get("surface",{}).duplicate(true)
	snapshot.erase("surface")
	if PlayerSaveStore.validate_snapshot(snapshot) != OK:
		return {"error":ERR_INVALID_DATA}
	var world := metadata.duplicate(true)
	world.world_id = metadata.save_id
	world.legacy_source = metadata.save_id
	world.difficulty = "Normal"
	world.generated = true
	world.played_seconds = surface.get("active_seconds",0)
	world.world_clock = surface.get("clock",0)
	var id := (str(metadata.save_id)+":portable_player").sha256_text().substr(0,32)
	var player := {"player_id":id,"name":"Viajante legado","appearance":snapshot.appearance,"level":1,
		"played_seconds":world.played_seconds,"created_at":metadata.created_at}
	var destination := library.world_directory(world)
	DirAccess.make_dir_recursive_absolute(destination)
	# Copy only immutable voxel records/index; validate before making metadata visible.
	for file: String in DirAccess.get_files_at(source):
		if file.begins_with("chunk_") or file in ["active.json","active.json.bak"]:
			var copy_error := DirAccess.copy_absolute(source.path_join(file),destination.path_join(file))
			if copy_error != OK:
				return {"error":copy_error}
	var terrain := WorldDeltaStore.new(destination,world)
	if terrain.load_world() != OK:
		return {"error":ERR_FILE_CORRUPT}
	var pieces: Dictionary = surface.get("structures",{})
	var quarantined := 0
	if int(surface.get("structure_module_version",1)) < 2:
		quarantined = pieces.size()
		var archive := AtomicDocument.new(destination.path_join("migration/legacy_structures.json"),1,{"world_id":world.world_id})
		archive.read()
		if archive.commit({"pieces":pieces,"reason":"P04 1m sockets incompatible with RC0 2m module; source retained"}) != OK:
			return {"error":ERR_CANT_CREATE}
		surface.structures = {}
		for row: Dictionary in surface.get("suppression",{}).values():
			var reasons: Array = []
			for reason: String in row.reasons:
				if not reason.begins_with("foundation:"):
					reasons.append(reason)
			row.reasons = reasons
		surface.structure_module_version = 2
	if SurfaceSaveValidator.validate(surface,snapshot.inventory) != OK:
		return {"error":ERR_INVALID_DATA}
	var portable := PortablePlayerStore.new(library.player_directory(player),player)
	var world_store := DirtyWorldStore.new(destination,world.world_id)
	var converted := world_store.migrate_1_to_2({"surface":surface,"sessions":{id:snapshot.spawn},"played_seconds":world.played_seconds})
	if converted.error != OK:
		return converted
	var world_doc := library.document("world",world_slot)
	var player_doc := library.document("player",player_slot)
	world_doc.read()
	player_doc.read()
	var error := AtomicBatch.commit(journal,[world_doc,player_doc,portable.document,world_store.document],
		[world,player,portable.payload(snapshot,float(player.played_seconds)),converted.data])
	return {"error":error,"quarantined":quarantined}
