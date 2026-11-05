extends Node3D
var failures := 0
var assertions := 0
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("WORLD_CORE_B "+label)
func quantity(store: InventoryState, id: String) -> int:
	var total := 0
	for stack: ItemStack in store._slots+store._pending:
		if stack != null and stack.item_id == id: total += stack.quantity
	return total
func _ready() -> void: _run.call_deferred()
func _run() -> void:
	var registry := ContainerService.new()
	var events: Dictionary = {}
	registry.completed_events = events
	var drops := WorldDropService.new()
	drops.containers = registry
	drops.point_for = func(_store: InventoryState) -> Vector3: return Vector3.ZERO
	var source := InventoryState.new()
	source.add_item("bi.resource.wood",20)
	check(drops.drop(source,source.slot_at(0).stack_uid,5,source.revision) == OK,"atomic loose drop")
	var id: String = registry.records.keys()[0]
	var loose: InventoryState = registry.inventories[id]
	check(registry.records[id].kind == "LooseItemDrop" and quantity(source,"bi.resource.wood") == 15,"loose ownership moved")
	var full := InventoryState.new()
	for index: int in 20: full.add_item("bi.weapon.starter_sword",1)
	check(drops.pickup(id,full,loose.revision,full.revision,Vector3.ZERO) == ERR_OUT_OF_MEMORY and quantity(loose,"bi.resource.wood") == 5,"full pickup preserves world stack")
	var partial := InventoryState.new()
	for index: int in 19: partial.add_item("bi.weapon.starter_sword",1)
	partial.add_item("bi.resource.wood",255)
	check(drops.pickup(id,partial,loose.revision,partial.revision,Vector3.ZERO) == OK and quantity(loose,"bi.resource.wood") == 4 and quantity(partial,"bi.resource.wood") == 256,"partial pickup conservation")
	var receiver := InventoryState.new()
	check(drops.pickup(id,receiver,loose.revision-1,receiver.revision,Vector3.ZERO) != OK and quantity(loose,"bi.resource.wood") == 4,"stale pickup rejects atomically")
	check(drops.pickup(id,receiver,loose.revision,receiver.revision,Vector3.ZERO) == OK and not registry.records.has(id) and quantity(receiver,"bi.resource.wood") == 4,"successful pickup removes empty world object")
	var chest := registry.create("chest",Vector3.ZERO)
	chest.add_item("bi.resource.wood",37)
	registry.records.chest.locked = true
	check(registry.request_open("chest",source.inventory_id,Vector3.ZERO) != OK and not registry.is_open("chest"),"open rejected by authority")
	registry.records.chest.locked = false
	check(registry.request_open("chest",source.inventory_id,Vector3.ZERO) == OK,"open accepted")
	var visual := ContainerVisual.new()
	add_child(visual)
	visual.configure(registry,"chest")
	check(visual.state == "OPEN" and visual.has_node("BodyVisual") and visual.has_node("LidVisual"),"chest visual reflects accepted state")
	registry.request_close(source.inventory_id)
	await get_tree().create_timer(.22).timeout
	check(visual.state == "CLOSED" and is_zero_approx(visual.lid.rotation.x),"close event drives lid")
	var start := Time.get_ticks_usec()
	check(registry.break_chest("chest") == OK and not registry.records.has("chest") and quantity(registry.inventories["broken_chest:chest"],"bi.resource.wood") == 37,"chest destruction conserves contents in persistent bag")
	check(registry.break_chest("chest") != OK,"chest cannot publish twice")
	var death_source := InventoryState.new()
	death_source.add_item("bi.resource.meat",10,{"spoilage":{"remaining":12}})
	death_source.add_item("bi.resource.stone",50)
	var original_uid: String = death_source.slot_at(0).stack_uid
	check(drops.publish_all(death_source,Vector3.ZERO,"death:test","DeathBagInventory","death:test") == OK,"death publication accepted")
	check(drops.publish_all(death_source,Vector3.ZERO,"death:test","DeathBagInventory","death:test") == OK and registry.inventories["death:test"].slot_at(0).stack_uid == original_uid,"death idempotent shared ownership")
	var bag: InventoryState = registry.inventories["death:test"]
	check(quantity(bag,"bi.resource.meat") == 10 and quantity(bag,"bi.resource.stone") == 50 and bag.slot_at(0).instance_data.spoilage.remaining == 12,"multi-stack bag keeps freshness")
	var document := AtomicDocument.new("user://qa_world_core_b/"+Crypto.new().generate_random_bytes(8).hex_encode()+".json",1,{"test":"world-containers"})
	check(document.commit({"containers":registry.snapshot(),"events":events}) == OK,"container document writes")
	var restored := AtomicDocument.new(document.path,1,document.identity)
	check(restored.read() == OK,"container document reload")
	var reloaded := ContainerService.new()
	reloaded.completed_events = restored.loaded.events
	check(reloaded.restore(restored.loaded.containers) == OK and reloaded.inventories["death:test"].slot_at(0).stack_uid == original_uid,"reload preserves world identity and UID")
	var retry := WorldDropService.new()
	retry.containers = reloaded
	check(retry.publish_all(death_source,Vector3.ZERO,"death:test") == OK and reloaded.records.size() == registry.records.size(),"reload does not duplicate death bag")
	registry.transfer_all(bag,receiver)
	registry.retire("death:test")
	death_source.add_item("bi.resource.stone",3)
	check(drops.publish_all(death_source,Vector3.ZERO,"death:test") == OK and not registry.records.has("death:test") and quantity(death_source,"bi.resource.stone") == 3,"event tombstone survives bag removal")
	var plan := InventoryPlan.new()
	var draft := drops.prepare(plan,Vector3.ZERO,source.time_source)
	registry.stage_transfer_all(plan,source,draft)
	registry.create("other",Vector3.ZERO)
	check(plan.commit() != OK and quantity(source,"bi.resource.wood") == 15 and not registry.records.has(draft.inventory_id),"stale publication has no source loss or visible bag")
	check(not visual.is_processing(),"no idle chest process")
	var presentation_us := {}
	for kind: String in ["LooseItemDrop","WorldDropBag","DeathBagInventory","Chest"]:
		var benchmark_id := "benchmark:"+kind
		registry.create(benchmark_id,Vector3.ZERO,kind)
		var total := 0
		var worst := 0
		for sample: int in 10:
			var began := Time.get_ticks_usec()
			var view := ContainerVisual.new()
			add_child(view)
			view.configure(registry,benchmark_id)
			var cost := Time.get_ticks_usec()-began
			total += cost
			worst = maxi(worst,cost)
			view.free()
		presentation_us[kind] = {"mean_us":total/10.0,"max_us":worst}
	print("WORLD_CORE_B ","PASS" if failures == 0 else "FAIL"," assertions=",assertions," failures=",failures," operations_us=",Time.get_ticks_usec()-start," presentation=",presentation_us)
	visual.free()
	get_tree().quit(1 if failures else 0)
