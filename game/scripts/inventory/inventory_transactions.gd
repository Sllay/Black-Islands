class_name InventoryTransactions
extends RefCounted
## Main-thread serialization boundary. Plans mutate detached copies; observers
## are notified only after every participant has adopted its committed state.
static var busy := false
static var successful := 0
static var stale := 0

static func clone(store: InventoryState) -> InventoryState:
	var copy := InventoryState.new()
	copy.time_source = store.time_source
	assert(copy.restore(store.snapshot()) == OK)
	return copy

static func commit(stores: Array[InventoryState], plans: Array[InventoryState], revisions: Array[int], publications: Array[InventoryPublication] = []) -> Error:
	if busy or stores.size() != plans.size() or stores.size() != revisions.size():
		return ERR_BUSY
	var ids: Dictionary = {}
	var stacks: Dictionary = {}
	for index: int in stores.size():
		if ids.has(stores[index].inventory_id) or stores[index].inventory_id != plans[index].inventory_id:
			return ERR_INVALID_PARAMETER
		ids[stores[index].inventory_id] = true
		if stores[index].revision != revisions[index]:
			stale += 1
			return ERR_ALREADY_IN_USE
		if InventoryState.new().restore(plans[index].snapshot()) != OK:
			return ERR_INVALID_DATA
		for stack: ItemStack in plans[index]._slots+plans[index]._pending:
			if stack != null:
				if stacks.has(stack.stack_uid):
					return ERR_INVALID_DATA
				stacks[stack.stack_uid] = true
	for publication: InventoryPublication in publications:
		if not publication.validate.is_valid() or not publication.validate.call():
			stale += 1
			return ERR_ALREADY_IN_USE
	busy = true
	for index: int in stores.size():
		stores[index].adopt_committed(plans[index])
	for publication: InventoryPublication in publications:
		publication.apply.call()
	for store: InventoryState in stores:
		store.changed.emit(store.revision)
	for publication: InventoryPublication in publications:
		if publication.notify.is_valid():
			publication.notify.call()
	busy = false
	successful += 1
	return OK

static func transfer(source: InventoryState, target: InventoryState, uid: String, quantity: int, source_revision: int, target_revision: int) -> Error:
	if source.revision != source_revision or target.revision != target_revision:
		stale += 1
		return ERR_ALREADY_IN_USE
	return InventoryCommands.transfer_plan(source,target,uid,quantity,source_revision,target_revision).commit()

static func output(target: InventoryState, outputs: Dictionary) -> Dictionary:
	var plan := clone(target)
	var overflow: Dictionary = {}
	for id: String in outputs:
		var remaining := plan.add_item(id,int(outputs[id]))
		if remaining > 0:
			overflow[id] = remaining
	var error := commit([target],[plan],[target.revision])
	return {"error":error,"overflow":overflow}

static func pay(target: InventoryState, costs: Dictionary) -> Error:
	var plan := clone(target)
	for id: String in costs:
		var remaining := int(costs[id])
		for index: int in InventoryState.CAPACITY:
			var row := plan.slot_at(index)
			if row.get("item_id") == id:
				var amount := mini(remaining,int(row.quantity))
				if amount > 0:
					plan.consume_uid(row.stack_uid,amount)
					remaining -= amount
		if remaining > 0:
			return ERR_UNAVAILABLE
	return commit([target],[plan],[target.revision])
