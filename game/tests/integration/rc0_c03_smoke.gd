extends Node3D
var failures := 0
var root_path := "user://qa_rc0_c03/"+Crypto.new().generate_random_bytes(8).hex_encode()

class ReadyTerrain extends VoxelTerrainAdapter:
	func collision_data_ready(_point: Vector3) -> bool:
		return true

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("RC0_C03 "+label)

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	_migrations()
	_ai()
	await _locomotion()
	_save_domains()
	print("RC0_C03 ","PASS" if failures == 0 else "FAIL"," failures=",failures)
	get_tree().quit(1 if failures else 0)

func _migrations() -> void:
	var old := AtomicDocument.new(root_path.path_join("chain.json"),1,{"id":"chain"})
	old.commit({"value":1})
	var target := AtomicDocument.new(old.path,3,old.identity)
	var step := func(data: Dictionary) -> Dictionary:
		data.value += 1
		return {"error":OK,"data":data}
	check(SchemaMigrations.read(target,{1:step,2:step}) == OK and target.loaded.value == 3,"explicit 1 -> 2 -> 3 chain")
	check(FileAccess.file_exists(old.path+".schema1"),"migration archives original")
	var future := AtomicDocument.new(old.path,4,old.identity)
	future.revision = target.revision
	future.commit({"value":4})
	check(SchemaMigrations.read(target,{1:step,2:step}) == ERR_UNAVAILABLE,"future schema safe reject")

func _ai() -> void:
	check(ClassDB.class_exists("LimboHSM"),"native pinned LimboAI loaded")
	var ledger := SurfaceLedger.new()
	var domain := MobDomain.new(ledger,ContainerService.new())
	for species: String in SurfaceCatalog.data().mobs:
		domain.spawn(species,species,Vector3.ZERO)
		var brain := LimboMobBrain.new()
		add_child(brain)
		brain.configure(SurfaceCatalog.data().mobs[species],domain.states[species])
		var context := {"attacked":false,"player_in_range":false,"territory_violation":false,"distance":5,"clock":0}
		brain.tick(context,Vector3.ONE)
		check(brain.command.kind == "WANDER","shared wander "+species)
		context.attacked = species != "boar"
		context.player_in_range = true
		context.territory_violation = true
		brain.tick(context,Vector3.ONE)
		var expected := "FLEE" if species == "chicken" else ("WARN_ATTACK" if species == "boar" else "CHASE")
		check(brain.command.kind == expected,"native behavior "+species)
		context.clock = 20
		context.distance = 1
		brain.tick(context,Vector3.ONE)
		check(brain.command.kind == ("FLEE" if species == "chicken" else "ATTACK"),"warn/chase -> attack "+species)
		var health: float = domain.states[species].health
		brain.deactivate()
		check(not brain.machine.is_active() and domain.states[species].health == health,"stasis keeps domain health")
		brain.free()
	var custom: Dictionary = SurfaceCatalog.data().mobs.chicken.duplicate(true)
	custom.rules = [{"all":{"time_of_day":"DAY"},"intent":"SLEEP"}]
	var sleeper := LimboMobBrain.new()
	add_child(sleeper)
	sleeper.configure(custom,domain.states.chicken)
	sleeper.tick({"time_of_day":"DAY"},Vector3.ZERO)
	check(sleeper.command.kind == "SLEEP","data-driven world time condition")
	sleeper.free()

func _locomotion() -> void:
	var floor_body := StaticBody3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20,.2,20)
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position.y = -.1
	floor_body.add_child(collision)
	add_child(floor_body)
	var obstacle := StaticBody3D.new()
	obstacle.collision_layer = CollisionLayers.STRUCTURE
	var wall := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1,2,.3)
	wall.shape = box
	obstacle.add_child(wall)
	obstacle.position = Vector3(0,1,-1)
	add_child(obstacle)
	var body := CharacterBody3D.new()
	body.collision_layer = CollisionLayers.MOB
	body.collision_mask = CollisionLayers.MOB_MASK
	var capsule := CollisionShape3D.new()
	var capsule_shape := CapsuleShape3D.new()
	capsule_shape.height = 1
	capsule_shape.radius = .2
	capsule.shape = capsule_shape
	capsule.position.y = .5
	body.add_child(capsule)
	body.position.y = .05
	add_child(body)
	var terrain := ReadyTerrain.new()
	var locomotion := MobLocomotion.new()
	locomotion.configure(body,terrain,2)
	for frame: int in 50:
		await get_tree().physics_frame
		locomotion.tick(1.0/60,Vector3.FORWARD,false)
	check(absf(body.position.x) > .2 and body.position.z < -.1,"obstacle steering through separate locomotion")
	body.position = Vector3(-9.95,.05,-9.95)
	await get_tree().physics_frame
	check(locomotion.steer(Vector3(-1,0,-1)).is_zero_approx(),"local ground probes refuse hole/edge")
	terrain.free()
	body.free()
	obstacle.free()
	floor_body.free()

func _save_domains() -> void:
	var library := FrontendLibrary.new(root_path.path_join("library"))
	library.create_world(1,"R1 Test",424242)
	library.create_world(2,"Independent",424243)
	library.create_player(1,"Player A",LPCCustomization.default_for("female"))
	var world := library.read("world",1)
	var profile_owner := library.read("player",1)
	# Exercise real C01 schema1 records, then migrate without loss.
	var player: PlayerActor = load("res://scenes/player/Player.tscn").instantiate()
	add_child(player)
	player.set_physics_process(false)
	player.spawned = true
	var session := FrontendSessionSave.new()
	check(session.prepare(library,1,1) == OK,"independent prepare")
	add_child(session)
	session.set_process(false)
	session.configure(player,session.portable)
	var surface := SurfaceRuntime.new()
	surface.player = player
	surface.farms = FarmSystem.new(surface.ledger)
	surface.building = SupportGraph.new()
	surface.building.ground = func(_cell: Vector3i) -> bool: return true
	surface.containers = ContainerService.new()
	surface.mobs = MobSimulation.new()
	surface.mobs.domain = MobDomain.new(surface.ledger,surface.containers)
	add_child(surface)
	surface.set_process(false)
	session.bind_surface(surface)
	check(session.flush() == OK,"initial schema2 commit")
	var revision := session.world_document.revision
	InventoryTransactions.output(player.inventory.state,{"bi.resource.stone":9})
	check(session.flush() == OK and session.last_write_report.player_documents == 1,"player-only inventory commit")
	check(session.last_write_report.world_regions == 0 and session.last_write_report.world_records == 0 and session.world_document.revision == revision,"inventory does not serialize/hash/write world")
	surface.farms.till(Vector3(2,0,2),true,1)
	surface.building.place("root","foundation",Vector3i.ZERO)
	var chest := surface.containers.create("chest",Vector3(1,.26,1))
	InventoryTransactions.output(chest,{"bi.resource.stone":5})
	check(session.flush() == OK and session.last_write_report.world_regions == 4,"only affected farm/suppression/structure/container regions")
	var source := player.inventory.state
	var row: Dictionary = {}
	for index: int in InventoryState.CAPACITY:
		if source.slot_at(index).get("item_id","") == "bi.resource.stone":
			row = source.slot_at(index)
			break
	check(InventoryTransactions.transfer(source,chest,row.stack_uid,3,source.revision,chest.revision) == OK,"cross-owner transfer")
	check(session.flush() == OK and session.last_write_report.world_regions == 1,"transfer writes player + chest region only")
	var terrain := WorldDeltaStore.new(library.world_directory(world),world)
	terrain.load_world()
	check(terrain.commit({Vector3i.ZERO:{"density":2000,"materials":[1,0,0,0]}}) == OK,"independent terrain record")
	var reload := FrontendSessionSave.new()
	check(reload.prepare(library,1,1) == OK,"fresh owner/world reload")
	var inventory := InventoryState.new()
	inventory.restore(reload.portable.loaded.inventory)
	var restored_chest := InventoryState.new()
	restored_chest.restore(reload.restored_surface.containers.chest.inventory)
	check(_quantity(inventory,"bi.resource.stone")+_quantity(restored_chest,"bi.resource.stone") == 314,"reload conservation across owners")
	check(reload.restored_surface.structures.has("root") and reload.restored_surface.farms.size() == 1,"world structures/farms preserved")
	check(reload.portable.loaded.appearance.body_type == "female" and not reload.portable.document.loaded.character.has("surface") and not reload.portable.document.loaded.character.has("spawn"),"portable appearance no world ownership")
	var second := FrontendSessionSave.new()
	check(second.prepare(library,2,1) == OK and second.portable.profile.player_id == profile_owner.player_id and second.restored_surface.is_empty(),"same player in independent world")
	check(second.portable.document.path == reload.portable.document.path and second.world_document.path != reload.world_document.path,"independent ownership paths")
	var reloaded_terrain := WorldDeltaStore.new(library.world_directory(world),world)
	check(reloaded_terrain.load_world() == OK and reloaded_terrain.revision == terrain.revision,"terrain deltas preserved independently")
	# C01 schemas, explicit upgrade and retained source archive.
	var legacy_player := AtomicDocument.new(root_path.path_join("old_profile.json"),1,{"player_id":"old"})
	legacy_player.commit(session.portable.payload(session.snapshot(),0))
	var new_player := AtomicDocument.new(legacy_player.path,2,legacy_player.identity)
	check(SchemaMigrations.read(new_player,{1:SchemaMigrations.player_1_to_2}) == OK and new_player.loaded.has("unlocks"),"C01 player migration")
	var old_world := AtomicDocument.new(root_path.path_join("old_world/world.json"),1,{"world_id":"old"})
	var snapshot := surface.ledger.snapshot()
	snapshot.merge({"structures":surface.building.pieces,"farms":surface.farms.plots,"containers":surface.containers.snapshot(),"mobs":{}},true)
	old_world.commit({"surface":snapshot,"sessions":{},"played_seconds":12})
	var migrated := DirtyWorldStore.new(old_world.path.get_base_dir(),"old")
	check(migrated.load_world() == OK and migrated.restore_surface().structures.has("root"),"C01 world -> regional manifest migration")
	_legacy_import(session.snapshot(),snapshot)
	surface.mobs.free()
	surface.building.ground = Callable()
	reload.free()
	second.free()
	session.free()
	player.free()
	surface.free()

func _legacy_import(player: Dictionary, surface: Dictionary) -> void:
	var source := root_path.path_join("p04")
	var metadata := {"schema_version":1,"slot_id":"slot_01","save_id":"p04_import_fixture","created_at":"2026-10-29T00:00:00Z",
		"last_played_at":"2026-10-29T00:00:00Z","display_name":"P04 preserved","world_seed":424242,
		"world_generation_version":IslandField.VERSION,"world_profile":IslandField.PROFILE_ID}
	SlotStore.new(source.path_join("profiles")).write_slot(metadata)
	var world_path := source.path_join("worlds/"+str(metadata.save_id))
	var terrain := WorldDeltaStore.new(world_path,metadata)
	terrain.commit({Vector3i.ZERO:{"density":123,"materials":[1,0,0,0]}})
	var old := PlayerSaveStore.new(world_path,metadata)
	player = player.duplicate(true)
	surface = surface.duplicate(true)
	surface.erase("structure_module_version")
	player.surface = surface
	check(old.commit(player) == OK,"P04 dev source saved")
	var destination := FrontendLibrary.new(root_path.path_join("imported"))
	var result := LegacySaveImport.run(destination,source.path_join("profiles"),source.path_join("worlds"))
	check(result.imported == 1 and result.errors.is_empty() and result.quarantined_pieces == 1,"legacy split preserves incompatible structural source")
	var imported := FrontendSessionSave.new()
	check(imported.prepare(destination,1,1) == OK and imported.restored_surface.containers.has("chest"),"legacy inventory/container/farm state reload")
	var world := destination.read("world",1)
	var delta := WorldDeltaStore.new(destination.world_directory(world),world)
	check(delta.load_world() == OK and delta.revision == 1,"legacy terrain copied/verified")
	check(FileAccess.file_exists(world_path.path_join("player.json")) and FileAccess.file_exists(destination.world_directory(world).path_join("migration/legacy_structures.json")),"legacy originals/quarantine retained")
	var again := LegacySaveImport.run(destination,source.path_join("profiles"),source.path_join("worlds"))
	check(again.imported == 0 and again.errors.is_empty(),"legacy import idempotent no duplicate")
	imported.free()

func _quantity(inventory: InventoryState, id: String) -> int:
	var count := 0
	for index: int in InventoryState.CAPACITY:
		var row := inventory.slot_at(index)
		if row.get("item_id","") == id:
			count += int(row.quantity)
	return count
