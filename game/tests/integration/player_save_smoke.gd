extends Node3D
var failures := 0
const DIRECTORY := "user://qa_p03_player_save"

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("P03_SAVE FAIL " + label)

func _run() -> void:
	for suffix: String in ["", ".bak", ".tmp"]:
		var path := DIRECTORY.path_join("player.json"+suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	var identity := {"save_id":"03030303030303030303030303030333","created_at":"2026-10-29T00:00:00Z",
		"world_seed":424242,"world_generation_version":1,"world_profile":IslandField.PROFILE_ID}
	var store := PlayerSaveStore.new(DIRECTORY,identity)
	_check(store.load_player() == OK and store.loaded.is_empty(), "P02 saves initialize lazily")
	var player: PlayerActor = load("res://scenes/player/Player.tscn").instantiate()
	player.position = Vector3(5,12,8)
	add_child(player)
	player.set_physics_process(false)
	var coordinator := PlayerSaveCoordinator.new()
	add_child(coordinator)
	coordinator.configure(player,store)
	coordinator._safe_feet = player.position
	player.state.max_health = 120
	player.state.max_stamina = 140
	player.state.set_health(73)
	player.state.set_stamina(61)
	player.inventory.state.equip("helmet",7)
	player.inventory.state.assign_hotbar(7,2)
	player.inventory.state.select_hotbar(7)
	player.inventory.state.wallet["bi.currency.coins"] = 42
	var uid: String = player.inventory.state.slot_at(0).stack_uid
	_check(coordinator.flush() == OK and store.revision == 1, "atomic player commit")
	var first := PlayerSaveStore.new(DIRECTORY,identity)
	_check(first.load_player() == OK and first.loaded.stats.health == 73 and first.loaded.inventory.slots[0].stack_uid == uid, "metadata/stack IDs on disk")
	player.state.set_health(62)
	_check(coordinator.flush() == OK and FileAccess.file_exists(DIRECTORY.path_join("player.json.bak")), "known-good backup")
	var loaded := PlayerSaveStore.new(DIRECTORY,identity)
	_check(loaded.load_player() == OK, "fresh store reload")
	var restored: PlayerActor = load("res://scenes/player/Player.tscn").instantiate()
	restored.position = Vector3.ZERO
	add_child(restored)
	restored.set_physics_process(false)
	var restore_coordinator := PlayerSaveCoordinator.new()
	add_child(restore_coordinator)
	restore_coordinator.configure(restored,loaded)
	_check(restored.position.is_equal_approx(Vector3(5,12,8)) and restored.state.current_health == 62 and restored.state.current_stamina == 61, "feet/stats restored")
	_check(restored.state.max_health == 120 and restored.state.max_stamina == 140, "authoritative stat capacities restored")
	_check(restored.inventory.state.selected == 7 and restored.inventory.state.equipment_at("helmet").item_id == "bi.armor.fiber_hat" and restored.inventory.state.wallet["bi.currency.coins"] == 42, "inventory/equipment/hotbar/wallet restored")
	_check(restored.inventory.state.slot_at(0).stack_uid == uid and restored.visual.configuration.selections == player.visual.configuration.selections, "same IDs and appearance")
	var serialized := JSON.stringify(loaded.loaded)
	for forbidden: String in ["texture", "animation_frame", "interpolation", "attack_state", "target", "dodge_timer"]:
		_check(not serialized.contains(forbidden), "no transient " + forbidden)
	var file := FileAccess.open(DIRECTORY.path_join("player.json"),FileAccess.WRITE)
	file.store_string("truncated")
	file.close()
	var backup := PlayerSaveStore.new(DIRECTORY,identity)
	_check(backup.load_player() == OK and backup.recovered and backup.loaded.stats.health == 73, "corrupt active recovers known-good backup")
	var future := FileAccess.open(DIRECTORY.path_join("player.json"),FileAccess.WRITE)
	future.store_string('{"save_schema_version":999}')
	future.close()
	_check(PlayerSaveStore.new(DIRECTORY,identity).load_player() == ERR_UNAVAILABLE and store.commit(coordinator.snapshot()) == ERR_UNAVAILABLE, "future schema never overwritten/fallen back")
	print("P03_SAVE ","PASS" if failures == 0 else "FAIL"," failures=",failures)
	get_tree().quit(1 if failures else 0)
