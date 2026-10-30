extends Node
const OPERATIONS := 5000
var expected: Dictionary = {}
var registry := ContainerService.new()
var player := InventoryState.new()
var sources: Array[InventoryState] = []
var rng := RandomNumberGenerator.new()
var sim: InventorySimulation
var crafting := CraftService.new()
var attempted: Dictionary = {}
var succeeded: Dictionary = {}
var failures := 0
var stale := 0
var audits := 0
func count_delta(id: String, value: int) -> void:
	expected[id] = int(expected.get(id,0))+value
func all_stores() -> Array[InventoryState]:
	var result: Array[InventoryState] = [player]
	for store: InventoryState in registry.inventories.values():
		result.append(store)
	return result
func audit(iteration: int) -> bool:
	var counts := {}
	var uids := {}
	for store: InventoryState in all_stores():
		for stack: ItemStack in store._slots+store._pending:
			if stack == null:
				continue
			var max_stack := ItemCatalog.resolve(stack.item_id).max_stack
			if stack.quantity < 1 or stack.quantity > max_stack or uids.has(stack.stack_uid):
				push_error("FUZZ ownership/limit at "+str(iteration))
				return false
			uids[stack.stack_uid] = true
			counts[stack.item_id] = int(counts.get(stack.item_id,0))+stack.quantity
	for id: String in expected:
		if int(counts.get(id,0)) != int(expected[id]):
			push_error("FUZZ conservation at%d %s expected%d actual%d"%[iteration,id,expected[id],counts.get(id,0)])
			return false
	for id: String in counts:
		if not expected.has(id):
			push_error("FUZZ unexpected output "+id)
			return false
	audits += 1
	return true
func scope(_context: Dictionary) -> ResourceScope:
	var result := ResourceScope.new()
	result.sources = sources
	result.destinations = [player]
	return result
func _ready() -> void:
	rng.seed = 320205000
	player.inventory_id = "fuzz.player"
	sources.append(player)
	for index: int in 2:
		sources.append(registry.create("fuzz.chest%d"%index,Vector3.ZERO))
	sim = InventorySimulation.new()
	sim.register(player)
	sim.bind_world(registry,func(_store: InventoryState) -> Vector3: return Vector3.ZERO,Callable())
	sim.unit_spoiled.connect(func(input: String, output: String) -> void:
		count_delta(input,-1)
		count_delta(output,1))
	for source: InventoryState in sources:
		for row: Array in [["bi.resource.wood",240],["bi.resource.stone",200],["bi.resource.meat",24],["bi.food.coconut",16],["bi.weapon.starter_sword",2]]:
			source.add_item(row[0],row[1])
			count_delta(row[0],row[1])
	crafting.resolve_scope = scope
	crafting.drops = sim.drops
	var start := Time.get_ticks_usec()
	for iteration: int in OPERATIONS:
		var source: InventoryState = sources[rng.randi_range(0,sources.size()-1)]
		var target: InventoryState = sources[(sources.find(source)+rng.randi_range(1,2))%sources.size()]
		var occupied: Array[int] = []
		for index: int in InventoryState.CAPACITY:
			if source._slots[index] != null:
				occupied.append(index)
		var choice := rng.randi_range(0,16)
		var key := str(choice)
		attempted[key] = int(attempted.get(key,0))+1
		var error: Error = ERR_UNAVAILABLE
		var stack: ItemStack = source._slots[occupied[rng.randi_range(0,occupied.size()-1)]] if not occupied.is_empty() else null
		match choice:
			0,1,2:
				if stack != null:
					error = InventoryCommands.reorganize(source,stack.stack_uid,rng.randi_range(0,19),source.revision)
			3,4,5:
				if stack != null:
					error = InventoryCommands.split(source,stack.stack_uid,["one","half","all"][choice-3],source.revision)
			6,7:
				if stack != null:
					var quantity := stack.quantity if choice == 6 else rng.randi_range(1,stack.quantity)
					error = InventoryCommands.transfer_plan(source,target,stack.stack_uid,quantity,source.revision,target.revision,true).commit()
			8:
				if stack != null:
					var plan := InventoryCommands.transfer_plan(source,target,stack.stack_uid,1,source.revision,target.revision,true)
					target.select_hotbar((target.selected+1)%8)
					error = plan.commit()
					if error == ERR_ALREADY_IN_USE:
						stale += 1
			9:
				sim.advance(float(rng.randi_range(1,8)))
				error = OK
			10:
				crafting.invalidate()
				error = crafting.enqueue(["bi.recipe.foundation","bi.recipe.ceiling","bi.recipe.pick"][rng.randi_range(0,2)],rng.randi_range(1,8))
			11:
				crafting.invalidate()
				crafting.refresh()
				if not crafting.queue.jobs.is_empty():
					var recipe := crafting.catalog.resolve(crafting.queue.jobs[0].recipe_id)
					crafting.queue.elapsed = recipe.duration
					error = crafting.request_completion(crafting.queue.jobs[0])
					if error == OK:
						for id: String in recipe.costs():
							count_delta(id,-int(recipe.costs()[id]))
						for output: CraftOutput in recipe.outputs:
							count_delta(output.item_id,output.quantity)
			12:
				if not crafting.queue.jobs.is_empty():
					error = crafting.queue.cancel(crafting.queue.jobs[rng.randi_range(0,crafting.queue.jobs.size()-1)].id)
			13:
				if not crafting.queue.jobs.is_empty():
					error = crafting.queue.reorder(crafting.queue.jobs[0].id,crafting.queue.jobs.size()-1)
			14:
				if stack != null:
					error = sim.drops.drop(source,stack.stack_uid,rng.randi_range(1,stack.quantity),source.revision)
			15:
				# Save/reload source record preserves UID/freshness, not duplicate ownership.
				error = source.restore(JSON.parse_string(JSON.stringify(source.snapshot())))
			16:
				# Explicit legitimate gathering/output mutation, including overflow.
				var id: String = ["bi.resource.wood","bi.resource.stone"][rng.randi_range(0,1)]
				var plan := InventoryPlan.new()
				InventoryCommands.output(plan.include(source),id,4)
				error = plan.commit()
				if error == OK:
					count_delta(id,4)
		if error == OK:
			succeeded[key] = int(succeeded.get(key,0))+1
		if not audit(iteration):
			failures += 1
			break
	print("INVENTORY_FUZZ ","PASS" if failures == 0 else "FAIL"," operations=",OPERATIONS," audits=",audits," stale_rejected=",stale," elapsed_ms=",(Time.get_ticks_usec()-start)/1000.0," attempted=",attempted," succeeded=",succeeded," conserved=",expected," bags=",registry.inventories.size()-2)
	sim.free()
	get_tree().quit(1 if failures else 0)
