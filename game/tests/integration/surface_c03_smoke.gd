extends Node
var failures := 0

func _ready() -> void:
	_prop_coverage()
	_overflow_conservation()
	_connected_support_benchmark()
	var ledger := SurfaceLedger.new()
	var containers := ContainerService.new()
	var mobs := MobDomain.new(ledger,containers)
	var data := SurfaceCatalog.data()
	_check(MobBrain.choose(data.mobs.chicken,{"attacked":true}) == "FLEE","passive flee")
	_check(MobBrain.choose(data.mobs.boar,{"territory_violation":true,"attacked":false}) == "WARN_ATTACK","neutral warning condition")
	_check(MobBrain.choose(data.mobs.zombie,{"player_in_range":true}) == "ATTACK","aggressive perception")
	var night := {"rules":[{"all":{"time_of_day":"NIGHT","pack_count":{"gte":3}},"intent":"ATTACK"}]}
	_check(MobBrain.choose(night,{"time_of_day":"DAY","pack_count":4}) == "WANDER" and MobBrain.choose(night,{"time_of_day":"NIGHT","pack_count":3}) == "ATTACK","time/pack conditions without species branches")
	_check(MobBrain.tier(0) == "ACTIVE" and MobBrain.tier(30) == "NEAR_PROXY" and MobBrain.tier(70) == "REGIONAL" and MobBrain.tier(200) == "STASIS","four simulation tiers")
	mobs.spawn("chickenA","chicken",Vector3(1,12,1))
	_check(mobs.spawn("chickenA","chicken",Vector3.ZERO) != OK,"duplicate mob identity rejected")
	var hit := HitPayload.new()
	hit.raw_damage = 8
	mobs.hit("chickenA",hit)
	_check(mobs.states.chickenA.health == 22,"health authority independent of actor")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(mobs.states))
	var restored := MobDomain.new(ledger,containers)
	restored.states = saved
	_check(restored.states.chickenA.id == "chickenA" and restored.states.chickenA.health == 22,"offscreen/save state retains identity and health")
	hit.raw_damage = 500
	mobs.hit("chickenA",hit)
	_check(mobs.states.chickenA.life == "DEATH","death phase before corpse")
	ledger.clock += .4
	mobs.evaluate()
	_check(mobs.states.chickenA.life == "CORPSE" and mobs.states.chickenA.harvest.health == 60,"new corpse harvest health")
	var player := InventoryState.new()
	player.inventory_id = "qa.player"
	var source: InventoryState = containers.inventories["corpse:chickenA"]
	var row := source.slot_at(0)
	_check(InventoryTransactions.transfer(source,player,row.stack_uid,1,source.revision,player.revision) == OK,"delicate corpse loot")
	var state := HarvestService.create("animal")
	var knife := HarvestService.strike(state,data.tools["bi.tool.knife"],0,"knife")
	var axe := HarvestService.strike(state,data.tools["bi.tool.axe"],0,"axe")
	_check(knife.outputs.get("bi.resource.light_hide",0) > axe.outputs.get("bi.resource.light_hide",0) and knife.outputs.get("bi.resource.meat",0) < axe.outputs.get("bi.resource.meat",0),"same corpse harvest core, different tool ratios")
	var harvest := mobs.harvest("chickenA","bi.tool.knife","once",0,player)
	_check(harvest.error == OK and mobs.harvest("chickenA","bi.tool.knife","once",0,player).error != OK,"corpse harvest cannot duplicate callback")
	mobs.decompose("chickenA")
	_check(not containers.records.has("corpse:chickenA") and not containers.records.has("deathbag:chickenA"),"passive unclaimed delicate loot policy")
	mobs.spawn("zombieA","zombie",Vector3(2,12,0))
	mobs.hit("zombieA",hit)
	ledger.clock += .4
	mobs.evaluate()
	source = containers.inventories["corpse:zombieA"]
	row = source.slot_at(0)
	var source_revision := source.revision
	var player_revision := player.revision
	_check(InventoryTransactions.transfer(source,player,row.stack_uid,1,source_revision,player_revision) == OK,"loot one protected unit")
	_check(mobs.decompose("zombieA") == OK and mobs.decompose("zombieA") != OK,"death bag conversion idempotent")
	var bag: InventoryState = containers.inventories["deathbag:zombieA"]
	_check(bag.slot_at(0).quantity == 2,"remaining two protected units moved, not copied")
	_check(InventoryTransactions.transfer(source,player,row.stack_uid,1,source_revision,player_revision) == ERR_ALREADY_IN_USE,"stale corpse loot after bag conversion rejected")
	_check(_count(player,"bi.resource.metal")+_count(bag,"bi.resource.metal") == 3,"corpse plus death bag conservation")
	var snapshot := containers.snapshot()
	var reloaded := ContainerService.new()
	_check(reloaded.restore(JSON.parse_string(JSON.stringify(snapshot))) == OK and _count(reloaded.inventories["deathbag:zombieA"],"bi.resource.metal") == 2,"protected inventory reload")
	_check(mobs.pack_player_death(player,Vector3.ZERO,"playerA") == OK and _count(player,"bi.resource.metal") == 0,"player death bag seam uses same atomic transfer")
	_check(data.hide_points["bi.resource.light_hide"] == 1 and data.hide_points["bi.resource.heavy_hide"] == 2,"integer hide recipe values")
	print("SURFACE_C03 ","PASS" if failures == 0 else "FAIL"," failures=",failures)
	get_tree().quit(1 if failures else 0)

func _overflow_conservation() -> void:
	var ledger := SurfaceLedger.new()
	var containers := ContainerService.new()
	var mobs := MobDomain.new(ledger,containers)
	var full := InventoryState.new()
	full.inventory_id = "qa.full"
	for index: int in InventoryState.CAPACITY:
		full.add_item("bi.tool.axe",1)
	mobs.spawn("overflow","chicken",Vector3.ZERO)
	var payload := HitPayload.new()
	payload.raw_damage = 500
	mobs.hit("overflow",payload)
	ledger.clock += .4
	mobs.evaluate()
	var result := mobs.harvest("overflow","bi.tool.knife","overflow_command",0,full)
	_check(result.error == OK and result.overflow == result.outputs,"full inventory owns none of overflow")
	var bag := containers.create("overflow_bag",Vector3.ZERO,"WorldDropBag")
	_check(InventoryTransactions.output(bag,result.overflow).error == OK,"overflow committed to one bag")
	_check(mobs.harvest("overflow","bi.tool.knife","overflow_command",0,full).error != OK,"repeat cannot make second overflow")
	for id: String in result.outputs:
		_check(_count(full,id)+_count(bag,id) == int(result.outputs[id]),"overflow conservation "+id)
	for reserve: Variant in mobs.states.overflow.harvest.reserves.values():
		_check(float(reserve) >= 0,"reserve remains nonnegative")

func _connected_support_benchmark() -> void:
	var graph := SupportGraph.new()
	graph.ground = func(cell: Vector3i) -> bool: return cell.y == 0 and cell.x%4 == 0
	for cluster: int in range(40):
		_check(graph.place("remote%d"%cluster,"foundation",Vector3i(200+cluster*8,0,0)) == OK,"remote root fixture")
	for x: int in range(0,81,4):
		_check(graph.place("root%d"%x,"foundation",Vector3i(x,0,0)) == OK,"bridge root fixture")
	for x: int in range(81):
		if x%4 != 0:
			_check(graph.place("deck%d"%x,"ceiling",Vector3i(x,0,0)) == OK,"connected deck fixture")
	for x: int in [20,40,60]:
		_check(graph.place("pillar%d"%x,"pillar",Vector3i(x,0,0)) == OK,"multiple pillar fixture")
	var removed := graph.remove("root28")
	_check(graph.last_benchmark.examined == 84 and removed.size() == 3,"connected support recompute local and selective")
	_check(graph.pieces.has("deck26") and graph.pieces.has("deck30") and graph.pieces.has("remote39"),"alternate roots and remote components survive")
	print("CONNECTED_SUPPORT_BENCHMARK before=124 ",graph.last_benchmark)

func _prop_coverage() -> void:
	var field := PropField.new(IslandField.new(424242))
	var definitions: Dictionary = {}
	var biomes: Dictionary = {}
	for z: int in range(-15,16):
		for x: int in range(-15,16):
			for row: Dictionary in field.candidates(Vector2i(x,z)):
				definitions[row.definition] = true
				biomes[row.biome] = true
			if definitions.size() == SurfaceCatalog.data().props.size() and biomes.size() == 4:
				print("PROP_COVERAGE seed424242 ",definitions.keys()," biomes=",biomes.keys())
				return
	_check(false,"all nine prop representatives and four biomes generated on actual island field")

func _count(store: InventoryState, id: String) -> int:
	var count := 0
	for index: int in InventoryState.CAPACITY:
		var row := store.slot_at(index)
		if row.get("item_id") == id:
			count += int(row.quantity)
	return count

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)
