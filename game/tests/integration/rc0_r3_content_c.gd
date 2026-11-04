extends Node3D
var failures := 0
var assertions := 0
class TestPresenter extends FoliagePresenter:
	func _ready() -> void: set_process(false)
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("CONTENT_C "+label)
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	var table := SpawnTable.new()
	var row: Dictionary = table.tables[0]
	var rng := RandomNumberGenerator.new()
	rng.seed = 80803
	var counts := {}
	var selection_start := Time.get_ticks_usec()
	for index: int in 10000:
		var entry := table.choose(table.entries(row,"SURFACE"),rng)
		counts[entry.prop_definition] = int(counts.get(entry.prop_definition,0))+1
	var selection_ms := (Time.get_ticks_usec()-selection_start)/1000.0
	check(counts["bi.prop.boulder.light"] > counts["bi.prop.boulder.dark"]*3,"surface dark less frequent")
	var cave := table.entries(row,"CAVE")
	check(cave[1].weight > cave[0].weight and cave[1].domain == "CAVE","domain weights independent of surface")
	var field := PropField.new(WorldFieldV2.new(424242))
	var first: Array = []
	var second: Array = []
	var placement_start := Time.get_ticks_usec()
	for index: int in 20:
		first.append_array(field.candidates(Vector2i(index-10,1),false))
		second.append_array(field.candidates(Vector2i(index-10,1),false))
	var placement_ms := (Time.get_ticks_usec()-placement_start)/1000.0
	check(AtomicDocument.same_value(first,second) and not first.is_empty(),"seed deterministic placement")
	check(PropVisual.parts(ContentData.find("props","bi.prop.boulder.light"))[0].mesh == PropVisual.parts(ContentData.find("props","bi.prop.boulder.dark"))[0].mesh,"light dark share one base mesh")
	var harvest := HarvestService.create("bi.harvest.boulder.iron")
	var tool := ItemCatalog.resolve("bi.tool.stone_pick").module("HarvestToolModule")
	var normal := HarvestService.strike(harvest,tool,0,"normal")
	var critical := HarvestService.strike(harvest,tool,0,"critical",true,2)
	check(critical.actual_damage > normal.actual_damage and critical.critical,"critical configurable")
	check(critical.outputs.get("bi.resource.stone",0) > 0 and critical.outputs.get("bi.resource.metal",0) > 0,"stone plus ore reserves")
	var wrong := ItemCatalog.resolve("bi.tool.axe").module("HarvestToolModule")
	check(HarvestService.strike(harvest,wrong,0,"wrong").actual_damage < normal.actual_damage,"tool affinity")
	harvest.health = 3
	var overkill := tool.duplicate(true)
	overkill.power = 500
	var final := HarvestService.strike(harvest,overkill,0,"overkill",true,3)
	check(final.actual_damage == 3 and final.state.health == 0,"actual damage clamp")
	for reserve: int in final.state.reserves.values(): check(reserve >= 0,"finite reserves")
	var runtime := SurfaceRuntime.new()
	for definition: Dictionary in SurfaceCatalog.data().props: runtime._definitions[definition.id] = definition
	var actor := PropActor.new()
	actor.runtime = runtime
	actor.definition_id = "bi.prop.mineral_root.iron"
	actor.spawn_id = "test.stable.mineral"
	add_child(actor)
	check(actor.get_node_or_null("BoulderMesh") != null and actor.get_node_or_null("OreOverlayMesh") != null,"one logical actor two visual meshes")
	check(actor.get_children().filter(func(child: Node) -> bool: return child is MeshInstance3D).size() == 2,"overlay exactly once")
	var ledger := SurfaceLedger.new()
	ledger.props[actor.spawn_id] = final.state
	var saved := JSON.parse_string(JSON.stringify(ledger.snapshot())) as Dictionary
	var restored := SurfaceLedger.new()
	check(restored.restore(saved) == OK and restored.props[actor.spawn_id].health == 0,"HP and destruction persist")
	check(AtomicDocument.same_value(restored.props[actor.spawn_id].reserves,final.state.reserves),"reserves persist")
	actor.free()
	actor = PropActor.new()
	actor.runtime = runtime
	actor.definition_id = "bi.prop.mineral_root.iron"
	actor.spawn_id = "test.stable.mineral"
	add_child(actor)
	check(actor.get_children().filter(func(child: Node) -> bool: return child is MeshInstance3D).size() == 2,"reinstantiation no overlay duplicate")
	actor.free()
	runtime.player = load("res://scenes/player/Player.tscn").instantiate()
	add_child(runtime.player)
	runtime.player.position = Vector3.ZERO
	runtime.player.set_physics_process(false)
	var presenter := TestPresenter.new()
	presenter.runtime = runtime
	presenter._center = Vector2i.ZERO
	presenter._desired = {Vector2i.ZERO:true}
	var spawn := {"id":"persist.prop","definition":"bi.prop.mineral_root.iron","point":[0,0,0],"yaw":0,"scale":1,"supported":true}
	presenter.generated[Vector2i.ZERO] = [spawn]
	runtime.ledger.props[spawn.id] = normal.state.duplicate(true)
	add_child(presenter)
	presenter._reconcile()
	presenter._reconcile()
	check(presenter.actors.size() == 1 and presenter.actors[spawn.id].get_node_or_null("OreOverlayMesh") != null,"near promotion one adapter/overlay")
	runtime.player.position = Vector3(20,0,0)
	presenter._reconcile()
	check(presenter.actors.is_empty(),"stream out disables adapter")
	runtime.player.position = Vector3.ZERO
	presenter._reconcile()
	check(presenter.actors.size() == 1 and runtime.ledger.props[spawn.id].health == normal.state.health,"stream in retains domain HP")
	runtime.ledger.props[spawn.id].health = 0
	presenter._reconcile()
	check(presenter.actors.is_empty(),"shared destruction removes both visual parts")
	presenter.free()
	runtime.player.free()
	var inventory := InventoryState.new()
	inventory.add_item("bi.resource.wood",12)
	var data := inventory.snapshot()
	data.slots[0].item_id = "bi.item.missing.after.update"
	check(InventoryState.new().restore(data) == OK and ItemCatalog.resolve("bi.item.missing.after.update").missing,"missing definition preserves owned item")
	var orphan: Dictionary = normal.state.duplicate(true)
	orphan.definition = "bi.harvest.removed.after.update"
	check(SurfaceSaveValidator.valid_harvest(orphan) and HarvestService.strike(orphan,tool,orphan.revision,"no-extraction").error == ERR_UNAVAILABLE,"orphan harvest preserved frozen without extraction")
	var storage_root := "user://qa_content_disk/"+Crypto.new().generate_random_bytes(8).hex_encode()
	runtime.farms = FarmSystem.new(runtime.ledger)
	runtime.building = SupportGraph.new()
	runtime.containers = ContainerService.new()
	runtime.mobs = MobSimulation.new()
	runtime.mobs.domain = MobDomain.new(runtime.ledger,runtime.containers)
	runtime.ledger.props["persist.prop"] = normal.state.duplicate(true)
	runtime.ledger.props["persist.prop"].position = [0,8,0]
	var world := DirtyWorldStore.new(storage_root.path_join("world"),"test.c03.world")
	check(world.load_world() == OK,"world storage initializes")
	world.bind(runtime)
	var staged := world.stage(DirtyWorldStore.global_state(runtime),{},0)
	check(staged.error == OK and world.document.commit(staged.data) == OK,"new prop state stored through real world manifest")
	world.committed()
	var reopened := DirtyWorldStore.new(storage_root.path_join("world"),"test.c03.world")
	check(reopened.load_world() == OK,"world manifest reload")
	var restored_world := reopened.restore_surface()
	check(restored_world.props["persist.prop"].health == normal.state.health and AtomicDocument.same_value(restored_world.props["persist.prop"].reserves,normal.state.reserves),"disk HP/reserves survive reload")
	check(SurfaceSaveValidator.validate(restored_world,InventoryState.new().snapshot()) == OK,"C03 state passes real save validator")
	runtime.mobs.free()
	print("CONTENT_C ","PASS" if failures == 0 else "FAIL"," assertions=",assertions," failures=",failures," distribution=",counts," weighted10000_ms=",selection_ms," legacy_plus_new_40patches_ms=",placement_ms)
	runtime.free()
	get_tree().quit(1 if failures else 0)
