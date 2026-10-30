class_name PlayerSaveCoordinator
extends Node
## Snapshot only committed domain state, outside combat/airborne autosave windows.
var actor: PlayerActor
var store: PlayerSaveStore
var last_error: Error = OK
var last_commit_ms := 0
var _poll := 0.0
var _since_save := 0.0
var _last_key := ""
var _safe_feet := Vector3.ZERO
var terrain_saver: TerrainSaveScheduler
var _autosaving := false

func configure(player: PlayerActor, storage: PlayerSaveStore) -> void:
	actor = player
	store = storage
	add_to_group("player_save_coordinators")
	if not store.loaded.is_empty():
		var data := store.loaded
		actor.inventory.state.restore(data.inventory)
		actor.visual.set_appearance(data.appearance)
		actor._refresh_appearance() # Weapon visual derives from hotbar, not a second save authority.
		actor.state.max_health = float(data.stats.get("max_health",100))
		actor.state.max_stamina = float(data.stats.get("max_stamina",100))
		actor.state.set_health(float(data.stats.health))
		actor.state.set_stamina(float(data.stats.stamina))
		actor.state.defense = float(data.stats.defense)
		actor.motor.facing = Vector3(data.spawn.facing[0],data.spawn.facing[1],data.spawn.facing[2]).normalized()
		if actor.motor.facing.is_zero_approx():
			actor.motor.facing = Vector3.FORWARD
		_safe_feet = Vector3(data.spawn.feet[0],data.spawn.feet[1],data.spawn.feet[2])
		actor.motor.request_spawn(_safe_feet)
		actor.combat.cancel()
		print("PLAYER_RESTORED revision=",store.revision," feet=",_safe_feet)

func _process(delta: float) -> void:
	_poll += delta
	_since_save += delta
	if _poll < 0.5 or actor == null or not actor.spawned:
		return
	_poll = 0
	if actor.is_on_floor() or (actor.water != null and actor.water.sample(actor.global_position).kind != "dry"):
		_safe_feet = actor.global_position
	if _since_save >= 8 and actor.combat.phase == PlayerCombat.Phase.READY and actor.is_on_floor():
		_autosaving = true
		flush()
		_autosaving = false

func snapshot() -> Dictionary:
	var feet := actor.global_position if actor.is_on_floor() else _safe_feet
	var config := actor.visual.configuration.duplicate(true)
	config.equipment_visuals = []
	var data := {"schema_version":1,"spawn":{"context":"surface","feet":[feet.x,feet.y,feet.z],
		"facing":[actor.motor.facing.x,actor.motor.facing.y,actor.motor.facing.z]},
		"appearance":config,"inventory":actor.inventory.state.snapshot(),
		"stats":{"health":actor.state.current_health,"max_health":actor.state.max_health,
			"stamina":actor.state.current_stamina,"max_stamina":actor.state.max_stamina,"defense":actor.state.defense}}
	var surface := get_tree().get_first_node_in_group("surface_runtime")
	if surface != null:
		data.surface = surface.snapshot()
	return data

func flush() -> Error:
	if terrain_saver != null and not _autosaving:
		last_error = terrain_saver.flush()
		if last_error != OK:
			return last_error
	if actor == null or (_autosaving and not actor.spawned):
		return OK
	var data := snapshot()
	var key := JSON.stringify(data,"",true).sha256_text()
	if key == _last_key:
		_since_save = 0
		return OK
	var start := Time.get_ticks_msec()
	last_error = store.commit(data)
	last_commit_ms = Time.get_ticks_msec()-start
	if last_error == OK:
		_last_key = key
		_since_save = 0
	else:
		push_error("Player save failed; previous record preserved: " + error_string(last_error))
	return last_error
