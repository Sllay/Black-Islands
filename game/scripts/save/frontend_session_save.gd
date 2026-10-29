class_name FrontendSessionSave
extends PlayerSaveCoordinator
## World truth and portable character records have independent files/identities.
## C03 replaces the initial coalesced world document with dirty domain records.
var world_document: AtomicDocument
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
	world_document = AtomicDocument.new(library.world_directory(world).path_join("surface.json"),1,{"world_id":world.world_id})
	error = world_document.read()
	if error != OK:
		return error
	portable = PortablePlayerStore.new(library.player_directory(player),player)
	error = portable.load_player()
	played = float(portable.document.loaded.get("played_seconds",player.played_seconds))
	_real_tick = Time.get_ticks_msec()
	return error

func configure(player: PlayerActor, storage: PlayerSaveStore) -> void:
	if not portable.loaded.is_empty():
		portable.loaded.appearance = portable.profile.appearance
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
		played += maxf(0,(now-_real_tick)/1000.0)
	_real_tick = now
	super(delta)

func flush() -> Error:
	if actor == null or not actor.spawned:
		return OK
	var snapshot_data := snapshot()
	last_error = PlayerSaveStore.validate_snapshot(snapshot_data)
	if last_error != OK:
		return last_error
	var world := world_document.loaded.duplicate(true)
	world.surface = snapshot_data.get("surface",{})
	if not world.has("sessions"):
		world.sessions = {}
	world.sessions[portable.profile.player_id] = snapshot_data.spawn
	world.played_seconds = float(world.get("played_seconds",0))+maxf(0,played-float(portable.document.loaded.get("played_seconds",0)))
	var started := Time.get_ticks_msec()
	last_error = AtomicBatch.commit(journal_path,[portable.document,world_document],[portable.payload(snapshot_data,played),world])
	if last_error == OK:
		portable.loaded = portable.bridge(portable.document.loaded)
		portable.revision = portable.document.revision
		_since_save = 0
		_update_cards(world)
	last_commit_ms = Time.get_ticks_msec()-started
	return last_error

func _update_cards(world: Dictionary) -> void:
	var doc := library.document("world",world_slot)
	if doc.read() == OK:
		doc.loaded.generated = true
		doc.loaded.played_seconds = world.played_seconds
		doc.loaded.world_clock = world.surface.get("clock",0)
		doc.commit(doc.loaded)
	var player := library.document("player",player_slot)
	if player.read() == OK:
		player.loaded.appearance = portable.document.loaded.character.appearance
		player.loaded.played_seconds = played
		player.commit(player.loaded)
