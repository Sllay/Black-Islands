class_name InventoryCommands
extends RefCounted
## Domain commands only. Plans are detached; UI receives results, never truth.
static func place(store: InventoryState, id: String, quantity: int, data: Dictionary = {}, uid: String = "") -> int:
	var definition := ItemCatalog.resolve(id)
	if definition == null or quantity <= 0:
		return maxi(0,quantity)
	var remaining := quantity
	var normalized := StackPolicy.normalize(definition,data,store.time_source.now)
	for stack: ItemStack in store._slots:
		if stack != null and stack.item_id == id and StackPolicy.compatible(id,stack.instance_data,normalized):
			var amount := mini(remaining,definition.max_stack-stack.quantity)
			stack.quantity += amount
			stack.revision += int(amount > 0)
			remaining -= amount
	for index: int in InventoryState.CAPACITY:
		if remaining == 0:
			break
		if store._slots[index] == null:
			var amount := mini(remaining,definition.max_stack)
			store._slots[index] = ItemStack.new(id,amount,normalized,uid)
			uid = ""
			remaining -= amount
	return remaining
static func output(copy: InventoryState, id: String, quantity: int, data: Dictionary = {}) -> void:
	var remainder := place(copy,id,quantity,data)
	var definition := ItemCatalog.resolve(id)
	while remainder > 0:
		var amount := mini(remainder,definition.max_stack)
		copy._pending.append(ItemStack.new(id,amount,StackPolicy.normalize(definition,data,copy.time_source.now)))
		remainder -= amount
static func transfer_plan(source: InventoryState, destination: InventoryState, uid: String, quantity: int, source_revision: int, destination_revision: int, partial: bool = false) -> InventoryPlan:
	var plan := InventoryPlan.new()
	if source == destination or quantity < 1:
		plan.error = ERR_INVALID_PARAMETER
		return plan
	var from := plan.include(source)
	var to := plan.include(destination)
	plan.revisions = [source_revision,destination_revision]
	var stack := from._by_uid(uid)
	if stack == null or quantity > stack.quantity:
		plan.error = ERR_INVALID_DATA
		return plan
	var remainder := place(to,stack.item_id,quantity,StackPolicy.copied_data(stack,from.time_source.now),uid if quantity == stack.quantity else "")
	plan.amount = quantity-remainder
	if plan.amount == 0 or (not partial and remainder > 0):
		plan.error = ERR_OUT_OF_MEMORY
		return plan
	from.consume_uid(uid,plan.amount)
	return plan
static func transferable(source: InventoryState, destination: InventoryState, uid: String) -> int:
	var stack := source._by_uid(uid)
	if stack == null:
		return 0
	var copy := InventoryTransactions.clone(destination)
	return stack.quantity-place(copy,stack.item_id,stack.quantity,StackPolicy.copied_data(stack,source.time_source.now))
static func reorganize(store: InventoryState, uid: String, destination: int, revision: int) -> Error:
	var plan := InventoryPlan.new()
	var copy := plan.include(store)
	plan.revisions[0] = revision
	if destination < 0 or destination >= InventoryState.CAPACITY:
		return ERR_INVALID_PARAMETER
	var stack := copy._by_uid(uid)
	if stack == null:
		return ERR_INVALID_DATA
	var origin := copy._slots.find(stack)
	if origin == destination:
		return OK
	var target := copy._slots[destination]
	if target != null and target.item_id == stack.item_id and StackPolicy.compatible(stack.item_id,target.instance_data,stack.instance_data):
		var amount := mini(stack.quantity,ItemCatalog.resolve(stack.item_id).max_stack-target.quantity)
		if amount == 0:
			return ERR_OUT_OF_MEMORY
		target.quantity += amount
		target.revision += 1
		copy.consume_uid(uid,amount)
	else:
		copy._slots[destination] = stack
		copy._slots[origin] = target
	return plan.commit()
static func split(store: InventoryState, uid: String, mode: String, revision: int) -> Error:
	var plan := InventoryPlan.new()
	var copy := plan.include(store)
	plan.revisions[0] = revision
	var source := copy._by_uid(uid)
	if source == null or source.quantity < 2 or mode not in ["one","half","all"]:
		return ERR_INVALID_PARAMETER
	var empty: Array[int] = []
	for index: int in InventoryState.CAPACITY:
		if copy._slots[index] == null:
			empty.append(index)
	if empty.is_empty():
		return ERR_OUT_OF_MEMORY
	var count := mini(source.quantity-1,empty.size()) if mode == "all" else 1
	@warning_ignore("integer_division")
	var amount := source.quantity/2 if mode == "half" else 1
	for child: int in count:
		copy._slots[empty[child]] = ItemStack.new(source.item_id,amount,StackPolicy.normalize(ItemCatalog.resolve(source.item_id),StackPolicy.copied_data(source,copy.time_source.now),copy.time_source.now))
	copy.consume_uid(uid,amount*count)
	return plan.commit()
static func assign(store: InventoryState, uid: String, index: int, equipment: String = "") -> Error:
	var plan := InventoryPlan.new()
	var copy := plan.include(store)
	var stack := copy._by_uid(uid)
	if stack == null:
		return ERR_INVALID_DATA
	var error := copy.assign_hotbar(index,copy._slots.find(stack)) if equipment.is_empty() else copy.equip(equipment,copy._slots.find(stack))
	return plan.commit() if error == OK else error
