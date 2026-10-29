class_name InventoryTransactions
extends RefCounted
## Main-thread serialization boundary. Plans mutate detached copies; observers
## are notified only after every participant has adopted its committed state.
static var busy := false
static var successful := 0
static var stale := 0

static func clone(store: InventoryState) -> InventoryState:
	var copy := InventoryState.new()
	assert(copy.restore(store.snapshot()) == OK)
	copy.inventory_id = store.inventory_id
	copy.owner_scope = store.owner_scope
	return copy

static func commit(stores: Array[InventoryState], plans: Array[InventoryState], revisions: Array[int]) -> Error:
	if busy or stores.size() != plans.size() or stores.size() != revisions.size():
		return ERR_BUSY
	var ids: Dictionary = {}
	for index: int in stores.size():
		if ids.has(stores[index].inventory_id):
			return ERR_INVALID_PARAMETER
		ids[stores[index].inventory_id] = true
		if stores[index].revision != revisions[index]:
			stale += 1
			return ERR_ALREADY_IN_USE
	busy = true
	for index: int in stores.size():
		stores[index].adopt_committed(plans[index])
	for store: InventoryState in stores:
		store.changed.emit(store.revision)
	busy = false
	successful += 1
	return OK

static func transfer(source: InventoryState, target: InventoryState, uid: String, quantity: int, source_revision: int, target_revision: int) -> Error:
	if source == target or quantity < 1:
		return ERR_INVALID_PARAMETER
	var from := clone(source)
	var to := clone(target)
	var stack := from.record_by_uid(uid)
	if stack.is_empty() or quantity > int(stack.quantity):
		return ERR_INVALID_DATA
	if to.add_item(stack.item_id,quantity,stack.instance_data) != 0:
		return ERR_OUT_OF_MEMORY
	if from.consume_uid(uid,quantity) != OK:
		return ERR_INVALID_DATA
	return commit([source,target],[from,to],[source_revision,target_revision])

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
