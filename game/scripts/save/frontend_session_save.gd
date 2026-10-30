class_name FrontendSessionSave
extends PlayerSaveCoordinator
## World truth and portable character records have independent files/identities.
## Independent owners, dirty regions, coalesced atomic ownership commits.
var world_document: AtomicDocument
var world_store: DirtyWorldStore
var restored_surface: Dictionary = {}
var world_played := 0.0
var last_write_report: Dictionary = {}
var portable: PortablePlayerStore
var library: FrontendLibrary
var world_slot: int
var player_slot: int
var journal_path: String
var played := 0.0
var _real_tick := 0

func prepare(profiles: FrontendLibrary, selected_world: int, selected_player: int) -> Error:
	library = profiles
	world_slot = selected_world
	player_slot = selected_player
	var world := library.read("world",world_slot)
	var player := library.read("player",player_slot)
	if world.is_empty() or player.is_empty():
		return ERR_INVALID_DATA
	journal_path = library.directory.path_join("pending_session.json")
	var error := AtomicBatch.recover(journal_path)
	if error != OK:
		return error
	portable = PortablePlayerStore.new(library.player_directory(player),player)
	error = portable.load_player()
	if error != OK:
		return error
	world_store = DirtyWorldStore.new(library.world_directory(world),world.world_id)
	error = world_store.load_world()
	if error != OK:
		return error
	world_document = world_store.document
	restored_surface = world_store.restore_surface()
	if restored_surface.has("load_error"):
		return ERR_FILE_CORRUPT
	if not restored_surface.is_empty():
		var inventory: Dictionary = portable.loaded.get("inventory",InventoryState.new().snapshot())
		error = SurfaceSaveValidator.validate(restored_surface,inventory)
		if error != OK:
			return error
	played = float(portable.document.loaded.get("played_seconds",player.played_seconds))
	world_played = float(world_document.loaded.get("played_seconds",world.played_seconds))
	_real_tick = Time.get_ticks_msec()
	return OK

func configure(player: PlayerActor, storage: PlayerSaveStore) -> void:
	var position: Dictionary = world_document.loaded.get("sessions",{}).get(portable.profile.player_id,{})
	if not position.is_empty():
		if portable.loaded.is_empty():
			portable.loaded = _fresh(player)
		portable.loaded.spawn = position
	super(player,storage)
	actor.inventory.state.inventory_id = str(portable.profile.player_id)+"/inventory"
	if portable.loaded.is_empty():
		actor.visual.set_appearance(portable.profile.appearance)
		actor._refresh_appearance()

func _fresh(player: PlayerActor) -> Dictionary:
	return {"schema_version":1,"appearance":portable.profile.appearance,"inventory":player.inventory.state.snapshot(),
		"stats":{"health":100,"stamina":100,"defense":0},"spawn":{"context":"surface","feet":[0,12,0],"facing":[0,0,-1]}}

func _process(delta: float) -> void:
	var now := Time.get_ticks_msec()
	if actor != null and actor.spawned:
		var elapsed := maxf(0,(now-_real_tick)/1000.0)
		played += elapsed
		world_played += elapsed
	_real_tick = now
	super(delta)

func flush() -> Error:
	if InventoryTransactions.busy:
		return ERR_BUSY
	if actor != null and actor.water != null and actor.water.domain != null and not _autosaving:
		if terrain_saver != null and terrain_saver.flush() != OK:
			return ERR_BUSY
		var water_error := actor.water.domain.flush()
		if water_error != OK:
			return water_error
	if terrain_saver != null and not _autosaving:
		last_error = terrain_saver.flush()
		if last_error != OK:
			return last_error
	if actor == null or (_autosaving and not actor.spawned) or world_store.runtime == null:
		return OK
	var snapshot_data := snapshot()
	last_error = PlayerSaveStore.validate_snapshot(snapshot_data)
	if last_error != OK:
		return last_error
	var started := Time.get_ticks_msec()
	var sessions: Dictionary = world_document.loaded.get("sessions",{}).duplicate(true)
	sessions[portable.profile.player_id] = snapshot_data.spawn
	var staged := world_store.stage(DirtyWorldStore.global_state(world_store.runtime),sessions,world_played)
	if staged.error != OK:
		return staged.error
	var payload := portable.payload(snapshot_data,played)
	var documents: Array[AtomicDocument] = []
	var payloads: Array[Dictionary] = []
	last_write_report = {"player_documents":0,"world_manifests":0,"world_regions":world_store.last_writes,"world_records":world_store.last_records}
	if not AtomicDocument.same_value(payload,portable.document.loaded):
		documents.append(portable.document)
		payloads.append(payload)
		last_write_report.player_documents = 1
	if not AtomicDocument.same_value(staged.data,world_document.loaded):
		documents.append(world_document)
		payloads.append(staged.data)
		last_write_report.world_manifests = 1
	last_error = AtomicBatch.commit(journal_path,documents,payloads) if not documents.is_empty() else OK
	if last_error == OK:
		world_store.committed()
		portable.loaded = portable.bridge(portable.document.loaded)
		portable.revision = portable.document.revision
		_since_save = 0
		_update_cards(staged.data)
	last_commit_ms = Time.get_ticks_msec()-started
	return last_error

func _update_cards(world: Dictionary) -> void:
	var doc := library.document("world",world_slot)
	if doc.read() == OK:
		doc.loaded.generated = true
		doc.loaded.played_seconds = world.played_seconds
		doc.loaded.world_clock = world.global.get("clock",0)
		doc.commit(doc.loaded)
	var player := library.document("player",player_slot)
	if player.read() == OK:
		player.loaded.appearance = portable.document.loaded.character.appearance
		player.loaded.played_seconds = played
		player.commit(player.loaded)

func bind_surface(surface: SurfaceRuntime) -> void:
	world_store.bind(surface)

func snapshot() -> Dictionary:
	if actor.inventory.simulation != null:
		actor.inventory.simulation.checkpoint()
	# Player-only capture: never calls SurfaceRuntime.snapshot or hashes world.
	var feet := actor.global_position if actor.is_on_floor() else _safe_feet
	var appearance := actor.visual.configuration.duplicate(true)
	appearance.equipment_visuals = []
	var data := {"schema_version":1,"spawn":{"context":"surface","feet":[feet.x,feet.y,feet.z],
		"facing":[actor.motor.facing.x,actor.motor.facing.y,actor.motor.facing.z]},
		"appearance":appearance,"inventory":actor.inventory.state.snapshot(),
		"stats":{"health":actor.state.current_health,"max_health":actor.state.max_health,
		"stamina":actor.state.current_stamina,"max_stamina":actor.state.max_stamina,"defense":actor.state.defense}}
	if actor.inventory.crafting != null:
		data.craft_queue = actor.inventory.crafting.service.queue.snapshot()
	return data
