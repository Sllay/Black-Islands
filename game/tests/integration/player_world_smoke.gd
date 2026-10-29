extends Node
## Actual P02 island/streaming + real player, isolated profile identity.

func _ready() -> void:
	_run.call_deferred()

func _wait_spawn(player: PlayerActor) -> bool:
	var deadline := Time.get_ticks_msec() + 60000
	while Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if player.spawned:
			return true
	return false

func _run() -> void:
	Profiles.store = SlotStore.new("user://qa_p03_world_profiles")
	var profile := {"schema_version":1, "slot_id":"slot_01", "save_id":"03030303030303030303030303030303",
		"created_at":"2026-10-29T00:00:00Z", "last_played_at":"2026-10-29T00:00:00Z", "display_name":"P03 Native QA",
		"world_seed":424242, "world_generation_version":1, "world_profile":IslandField.PROFILE_ID}
	if Profiles.store.write_slot(profile) != OK or Profiles.select_slot("slot_01") != OK:
		_fail("profile fixture")
		return
	var main: Node3D = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	var session: WorldSession = main.get_node("WorldRoot/WorldSession")
	var player := session.pawn
	if not player is PlayerActor or not await _wait_spawn(player):
		_fail("real player/spawn")
		return
	player.inspect_at(Vector3(60,40,0))
	if not await _wait_spawn(player):
		_fail("slope residency")
		return
	Input.action_press("move_right")
	Input.action_press("run")
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline and player.global_position.x < 78:
		await get_tree().physics_frame
	Input.action_release("move_right")
	Input.action_release("run")
	for frame: int in range(60):
		await get_tree().physics_frame
		if player.is_on_floor() and Vector2(player.velocity.x, player.velocity.z).length() < 0.1:
			break
	var ring := session.streamer.metrics()
	if player.global_position.x < 78 or ring.center.x != 1 or ring.horizontal_regions != 9:
		_fail("native WorldChunk crossing " + str(player.player_report()) + " " + str(ring))
		return
	if not player.is_on_floor() or player.global_position.y < 5 or player.get_floor_normal().y < cos(deg_to_rad(50)):
		_fail("native slope/floor " + str(player.player_report()))
		return
	if session.terrain.native.lod_count != 4 or session.terrain.native.mesh_block_size != 32 or player.get_node("Viewer").view_distance != 192:
		_fail("world budget changed")
		return
	print("PLAYER_WORLD PASS native slope+crossing ", player.player_report(), " ring=", ring)
	get_tree().quit()

func _fail(message: String) -> void:
	push_error("PLAYER_WORLD FAIL " + message)
	get_tree().quit(1)
