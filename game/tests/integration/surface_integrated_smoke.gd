extends Node
## Real Main/voxel/player/services, isolated stable QA save identity.
const SAVE_ID := "04040404040404040404040404040404"
var failures := 0
var session: WorldSession
var surface: SurfaceRuntime
var player: PlayerActor

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("P04_INTEGRATED "+label)

func _frames(count: int) -> void:
	for frame: int in count:
		await get_tree().physics_frame

func _resident() -> bool:
	var deadline := Time.get_ticks_msec()+60000
	while Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		var tasks: Dictionary = session.terrain.statistics().engine.tasks
		if player.spawned and tasks.generation == 0 and tasks.meshing == 0 and tasks.main_thread == 0:
			return true
	return false

func _run() -> void:
	Profiles.store = SlotStore.new("user://qa_p04_profiles")
	var profile := {"schema_version":1,"slot_id":"slot_01","save_id":SAVE_ID,"created_at":"2026-10-29T00:00:00Z",
		"last_played_at":"2026-10-29T00:00:00Z","display_name":"P04 integrated QA","world_seed":424242,
		"world_generation_version":1,"world_profile":IslandField.PROFILE_ID}
	for suffix: String in ["", ".bak", ".tmp"]:
		var path := "user://qa_worlds/"+SAVE_ID+"/player.json"+suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)
	Profiles.store.write_slot(profile)
	Profiles.select_slot("slot_01")
	var main: Node3D = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	session = main.get_node("WorldRoot/WorldSession")
	surface = session.surface
	player = session.pawn
	_check(await _resident(),"native island ready")
	await _frames(70)
	var tree := surface.qa_resource("tree","bi.tool.axe")
	_check(tree.has("result") and tree.result.error == OK,"real tree output")
	# QA fixtures may provision building resources; actual harvesting is above,
	# while recipe payment/capacity/conservation are exercised by domain tests.
	surface.deliver({"bi.resource.wood":100},player.position)
	player.inspect_at(Vector3(0,40,0))
	_check(await _resident(),"return to clearing")
	player.state.set_health(100)
	player.combat.cancel()
	surface.qa.c02()
	_check(surface.qa.result.get("density_unchanged",false),"hoe changed material without density")
	_check(surface.qa.result.get("crop_output",{}).get("bi.food.turnip") == 3,"integrated crop output")
	_check(surface.building.pieces.size() >= 5 and surface.containers.records.size() >= 1,"integrated building/container")
	# Local path release actually restores the material, not just a ledger flag.
	var regrowth_point := Vector3(-3.5,12.02,-3.5)
	_check(session.edits.apply(regrowth_point,.55,true,2) == OK,"paint path soil")
	surface.ledger.suppress(regrowth_point,"qa_path")
	surface.ledger.release(regrowth_point,"qa_path")
	surface.qa_advance(6)
	await _frames(40)
	surface._regrow()
	_check(not surface.ledger.suppressed(regrowth_point) and session.terrain.material_at(regrowth_point) == 1,"local soil regrowth restores grass material")
	var mob_id := surface.ledger.new_id("qa_mob")
	var mob_point := player.position+Vector3(0,0,-2)
	surface.mobs.domain.spawn(mob_id,"chicken",mob_point)
	surface.mobs.reconcile()
	var hit := HitPayload.new()
	hit.raw_damage = 5
	surface.mobs.domain.hit(mob_id,hit)
	_check(surface.mobs.actors.has(mob_id),"one active actor created")
	player.inspect_at(Vector3(150,40,0))
	_check(await _resident(),"far streaming")
	await _frames(20)
	_check(not surface.mobs.actors.has(mob_id) and surface.mobs.domain.states[mob_id].health == 25,"stasis removes body, retains HP")
	var return_point := MobDomain._point(surface.mobs.domain.states[mob_id])+Vector3(0,5,3)
	player.inspect_at(return_point)
	_check(await _resident(),"return streaming")
	await _frames(20)
	var count := 0
	for actor: Node in surface.mobs.get_children():
		if actor is MobActor and actor.entity_id == mob_id:
			count += 1
	_check(count == 1 and surface.mobs.domain.states[mob_id].health == 25,"same ID/HP and exactly one restored actor")
	# Corpse/bag lifecycle shares generic harvest/inventory on this same island.
	hit.raw_damage = 500
	surface.mobs.domain.hit(mob_id,hit)
	surface.ledger.clock += .4
	surface.mobs.domain.evaluate()
	_check(surface.mobs.domain.states[mob_id].life == "CORPSE","actual session corpse")
	var corpse: Dictionary = surface.mobs.domain.states[mob_id]
	var corpse_inventory: InventoryState = surface.containers.inventories[corpse.corpse_inventory]
	var feather := corpse_inventory.slot_at(0)
	var chest_id := surface.ledger.new_id("test_chest")
	var chest := surface.containers.create(chest_id,player.position)
	_check(InventoryTransactions.transfer(corpse_inventory,chest,feather.stack_uid,1,corpse_inventory.revision,chest.revision) == OK,"corpse delicate loot transaction")
	var crop_inventory := InventoryState.new()
	crop_inventory.inventory_id = "qa.harvest_probe"
	var extracted := surface.mobs.domain.harvest(mob_id,"bi.tool.knife","integrated",0,crop_inventory)
	_check(extracted.error == OK,"same generic corpse extraction core")
	# Put actual extraction in a persisted world container, not a detached test bag.
	_check(surface.containers.transfer_all(crop_inventory,chest) == OK,"harvest ownership committed")
	surface.objects.reconcile()
	await _frames(15)
	player.state.set_health(87)
	player.combat.cancel()
	_check(session.player_save.flush() == OK,"joined player/surface snapshot commit")
	var before := session.player_save.store.loaded.duplicate(true)
	var fresh := PlayerSaveStore.new(session.player_store.directory,profile)
	_check(fresh.load_player() == OK,"fresh joined save read")
	_check(fresh.loaded.surface.props == JSON.parse_string(JSON.stringify(before.surface.props)),"prop deltas unchanged on reload")
	_check(fresh.loaded.surface.structures.size() == surface.building.pieces.size() and fresh.loaded.surface.farms.size() == surface.farms.plots.size(),"farm/structure state reload")
	_check(fresh.loaded.surface.farms.size() == 1,"farm survived collider stream-out/in")
	_check(fresh.loaded.surface.mobs[mob_id].id == mob_id and fresh.loaded.surface.mobs[mob_id].life == "CORPSE","corpse identity persisted")
	var restored_containers := ContainerService.new()
	_check(restored_containers.restore(fresh.loaded.surface.containers) == OK,"container state reload")
	_check(restored_containers.inventories[chest_id].slot_at(0).quantity == 1,"no duplicate corpse loot on reload")
	var duplicated_save := fresh.loaded.duplicate(true)
	duplicated_save.surface.containers[chest_id].inventory.slots[0] = duplicated_save.inventory.slots[0].duplicate(true)
	_check(PlayerSaveStore.validate_snapshot(duplicated_save) != OK,"save ownership duplication rejected")
	print("P04_INTEGRATED ","PASS" if failures == 0 else "FAIL"," failures=",failures," report=",surface.report()," bytes=",FileAccess.get_file_as_bytes(session.player_store.directory.path_join("player.json")).size())
	get_tree().quit(1 if failures else 0)
