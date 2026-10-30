extends Node
var failures := 0
var assertions := 0
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("R3_INVENTORY_A "+label)
func count(store: InventoryState, id: String, include_pending: bool = true) -> int:
	var total := 0
	var stacks: Array = store._slots.duplicate()
	if include_pending:
		stacks.append_array(store._pending)
	for stack: ItemStack in stacks:
		if stack != null and stack.item_id == id:
			total += stack.quantity
	return total
func fresh(quantity: int, remaining: float) -> ItemStack:
	return ItemStack.new("bi.food.coconut",quantity,{"spoilage":{"remaining":remaining,"started_at":0.0}})
func _ready() -> void:
	_split_merge()
	_spoilage()
	_transactions()
	print("R3_INVENTORY_A ","PASS" if failures == 0 else "FAIL"," failures=",failures," assertions=",assertions)
	get_tree().quit(1 if failures else 0)
func _split_merge() -> void:
	var store := InventoryState.new()
	store._slots[0] = fresh(11,36)
	var uid := store._slots[0].stack_uid
	check(InventoryCommands.split(store,uid,"half",store.revision) == OK,"split half")
	check(store._slots[0].quantity == 6 and store._slots[1].quantity == 5,"half rounds child down")
	check(StackPolicy.freshness(store.slot_at(1),0) == .12,"split inherits12percent")
	check(InventoryCommands.split(store,uid,"one",store.revision) == OK and store._slots[2].quantity == 1,"split one")
	store = InventoryState.new()
	store._slots[0] = ItemStack.new("bi.resource.meat",50,{"spoilage":{"remaining":14.4,"started_at":0.0}})
	for slot: int in range(1,17):
		store._slots[slot] = ItemStack.new("bi.weapon.starter_sword",1)
	uid = store._slots[0].stack_uid
	check(InventoryCommands.split(store,uid,"all",store.revision) == OK,"split all")
	check(store._slots[0].quantity == 47 and store._slots[17].quantity == 1 and store._slots[19].quantity == 1,"all is singletons bounded by empty slots")
	check(is_equal_approx(StackPolicy.freshness(store.slot_at(19),0),.12),"all inherits12percent")
	check(InventoryCommands.split(store,uid,"one",store.revision) == ERR_OUT_OF_MEMORY,"full rejects split")
	store = InventoryState.new()
	store._slots[0] = fresh(30,30)
	store._slots[1] = fresh(20,300)
	uid = store._slots[1].stack_uid
	check(InventoryCommands.reorganize(store,uid,0,store.revision) == OK,"partial merge")
	check(store._slots[0].quantity == 32 and store._slots[1].quantity == 18,"partial remainder")
	check(StackPolicy.freshness(store.slot_at(0),0) == .1 and StackPolicy.freshness(store.slot_at(1),0) == 1,"destination timer wins remainder keeps source")
	store = InventoryState.new()
	store._slots[0] = fresh(20,30)
	store._slots[1] = fresh(10,300)
	check(InventoryCommands.reorganize(store,store._slots[0].stack_uid,1,store.revision) == OK and StackPolicy.freshness(store.slot_at(1),0) == 1,"reverse merge uses new destination")
	uid = store._slots[1].stack_uid
	check(InventoryCommands.assign(store,uid,0) == OK,"hotbar reference")
	check(InventoryCommands.reorganize(store,uid,5,store.revision) == OK and store.hotbar_at(0).stack_uid == uid,"move keeps UID/hotbar")
	store.add_item("bi.resource.wood",5)
	var wood := store._slots[0].stack_uid
	check(InventoryCommands.reorganize(store,wood,5,store.revision) == OK and store._slots[0].stack_uid == uid,"different item swap")
	check(InventoryCommands.assign(store,wood,1) == ERR_INVALID_DATA,"resource hotbar rejected")
	InventoryLayoutPolicy.begin(store.inventory_id)
	check(InventoryLayoutPolicy.compact(store,store.revision) == ERR_BUSY,"organize blocked while drag")
	InventoryLayoutPolicy.end(store.inventory_id)
	check(InventoryLayoutPolicy.compact(store,store.revision) == OK,"explicit organize")
func _spoilage() -> void:
	var store := InventoryState.new()
	store.add_item("bi.resource.meat",10)
	var sim := InventorySimulation.new()
	sim.register(store)
	sim.advance(120)
	check(count(store,"bi.resource.meat") == 9 and count(store,"bi.resource.rotten_flesh") == 1,"one unit at a time")
	var row := store.slot_at(0)
	check(StackPolicy.freshness(row,sim.clock.now) == 1,"remaining stack timer resets")
	sim.advance(1)
	check(count(store,"bi.resource.meat") == 9,"second unit gets full cycle")
	var snapshot := JSON.parse_string(JSON.stringify(store.snapshot())) as Dictionary
	var reload := InventoryState.new()
	check(reload.restore(snapshot) == OK,"schema2 reload")
	check(is_equal_approx(StackPolicy.freshness(reload.slot_at(0),0),119.0/120),"remaining time persists without offline clock")
	snapshot.schema_version = 1
	snapshot.erase("pending_outputs")
	check(InventoryState.new().restore(snapshot) == OK,"schema1 additive migration")
	store = InventoryState.new()
	store.add_item("bi.resource.meat",10)
	for slot: int in range(1,20):
		store._slots[slot] = ItemStack.new("bi.weapon.starter_sword",1)
	sim.free()
	sim = InventorySimulation.new()
	sim.register(store)
	sim.advance(120)
	check(count(store,"bi.resource.meat") == 9 and count(store,"bi.resource.rotten_flesh") == 1 and store._pending.size() == 1,"full spoiled output retained")
	reload = InventoryState.new()
	check(reload.restore(JSON.parse_string(JSON.stringify(store.snapshot()))) == OK and reload._pending.size() == 1,"pending output persists")
	var registry := ContainerService.new()
	var drops := WorldDropService.new()
	drops.containers = registry
	drops.point_for = func(_store: InventoryState) -> Vector3: return Vector3.ZERO
	check(drops.drain_pending(store) == OK and store._pending.is_empty(),"pending becomes atomic world bag")
	check(registry.inventories.size() == 1 and count(registry.inventories.values()[0],"bi.resource.rotten_flesh") == 1,"overflow exists exactly once")
	sim.free()
func _transactions() -> void:
	var source := InventoryState.new()
	var target := InventoryState.new()
	source.inventory_id = "a"
	target.inventory_id = "b"
	source.add_item("bi.food.coconut",20)
	target._slots[0] = fresh(30,30)
	for index: int in range(1,20):
		target._slots[index] = ItemStack.new("bi.weapon.starter_sword",1)
	var uid := source._slots[0].stack_uid
	var plan := InventoryCommands.transfer_plan(source,target,uid,20,source.revision,target.revision,true)
	check(plan.amount == 2 and plan.commit() == OK,"full transfer maximum possible")
	check(count(source,"bi.food.coconut") == 18 and count(target,"bi.food.coconut") == 32,"partial conservation")
	plan = InventoryCommands.transfer_plan(target,source,target._slots[0].stack_uid,3,target.revision,source.revision)
	source.select_hotbar(1)
	check(plan.commit() == ERR_ALREADY_IN_USE and count(source,"bi.food.coconut") == 18,"stale rejects all participants")
	var registry := ContainerService.new()
	var drops := WorldDropService.new()
	drops.containers = registry
	drops.point_for = func(_store: InventoryState) -> Vector3: return Vector3.ZERO
	check(drops.drop(source,uid,5,source.revision) == OK,"safe drop")
	check(count(source,"bi.food.coconut") == 13 and count(registry.inventories.values()[0],"bi.food.coconut") == 5,"drop conservation")
	plan = InventoryPlan.new()
	var copy := plan.include(source)
	var bag := drops.prepare(plan,Vector3.ZERO,source.time_source)
	plan.include(bag)
	copy.consume_uid(uid,1)
	registry.create("other",Vector3.ONE)
	check(plan.commit() == ERR_ALREADY_IN_USE and count(source,"bi.food.coconut") == 13 and not registry.inventories.has(bag.inventory_id),"world publication stale prevents removal and spawn")
	var state := InventoryState.new()
	state.add_item("bi.tool.watering_can",1)
	uid = state._slots[0].stack_uid
	WaterContainer.change(state,uid,7)
	var reload := InventoryState.new()
	check(reload.restore(JSON.parse_string(JSON.stringify(state.snapshot()))) == OK and WaterContainer.volume(reload,uid) == 7,"water module preserved")
