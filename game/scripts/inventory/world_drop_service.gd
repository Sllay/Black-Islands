class_name WorldDropService
extends RefCounted
## Prepared world ownership; no mesh/scene creation in the transaction domain.
var containers: ContainerService
var point_for: Callable
var after_publish: Callable
func prepare(plan: InventoryPlan, point: Vector3, clock: GameplayTimeSource, kind: String = "WorldDropBag", identity: String = "", event_id: String = "") -> InventoryState:
	if containers == null or not point.is_finite() or kind not in ["LooseItemDrop","WorldDropBag","DeathBagInventory"]:
		plan.error = ERR_UNAVAILABLE
		return null
	var id := identity if not identity.is_empty() else "drop_"+Crypto.new().generate_random_bytes(12).hex_encode()
	var inventory := InventoryState.new()
	inventory.inventory_id = id
	inventory.owner_scope = "WORLD"
	inventory.time_source = clock
	var expected := containers.revision
	var publication := InventoryPublication.new()
	publication.validate = func() -> bool: return containers.revision == expected and not containers.inventories.has(id) and (event_id.is_empty() or not containers.completed_events.has(event_id))
	publication.apply = func() -> void:
		containers.inventories[id] = inventory
		containers.records[id] = {"id":id,"position":[point.x,point.y,point.z],"kind":kind,"event_id":event_id,"deadline":-1,"policy":"persistent"}
		if not event_id.is_empty(): containers.completed_events[event_id] = id
		containers._index_record(id,point)
		inventory.changed.connect(containers._inventory_changed.bind(id))
		containers.revision += 1
	publication.notify = func() -> void:
		containers.changed.emit(id)
		if after_publish.is_valid():
			after_publish.call()
	plan.publications.append(publication)
	return inventory
func publish_all(source: InventoryState, point: Vector3, event_id: String, kind: String = "DeathBagInventory", identity: String = "", retire_source: bool = false) -> Error:
	if containers == null or event_id.is_empty(): return ERR_INVALID_PARAMETER
	if containers.completed_events.has(event_id): return OK
	var plan := InventoryPlan.new()
	var bag := prepare(plan,point,source.time_source,kind,identity,event_id)
	if bag == null: return plan.error
	containers.stage_transfer_all(plan,source,bag)
	if retire_source:
		var publication := InventoryPublication.new()
		publication.validate = func() -> bool: return containers.inventories.get(source.inventory_id) == source
		publication.apply = func() -> void: containers.retire(source.inventory_id)
		publication.notify = func() -> void: containers.changed.emit(source.inventory_id)
		plan.publications.append(publication)
	return plan.commit()

func pickup(id: String, destination: InventoryState, source_revision: int, destination_revision: int, point: Vector3) -> Error:
	if containers == null or not containers.records.has(id) or containers.records[id].kind != "LooseItemDrop": return ERR_UNAVAILABLE
	if not containers.access_policy.allows(containers,id,destination.inventory_id,point,4): return ERR_UNAUTHORIZED
	var source: InventoryState = containers.inventories[id]
	var plan := InventoryPlan.new()
	var from := plan.include(source)
	var to := plan.include(destination)
	plan.revisions = [source_revision,destination_revision]
	for stack: ItemStack in from._slots+from._pending:
		if stack == null: continue
		var remainder := InventoryCommands.place(to,stack.item_id,stack.quantity,StackPolicy.copied_data(stack,from.time_source.now),stack.stack_uid)
		var taken := stack.quantity-remainder
		if taken <= 0: continue
		plan.amount += taken
		if stack in from._slots: from.consume_uid(stack.stack_uid,taken)
		else:
			stack.quantity -= taken
			if stack.quantity == 0: from._pending.erase(stack)
	if plan.amount == 0: return ERR_OUT_OF_MEMORY
	var empty := from._slots.all(func(stack: ItemStack) -> bool: return stack == null) and from._pending.is_empty()
	var publication := InventoryPublication.new()
	publication.validate = func() -> bool: return containers.inventories.get(id) == source and containers.access_policy.allows(containers,id,destination.inventory_id,point,4)
	publication.apply = func() -> void:
		if empty: containers.retire(id)
	publication.notify = func() -> void:
		containers.changed.emit(id)
		if after_publish.is_valid(): after_publish.call()
	plan.publications.append(publication)
	return plan.commit()

func drop(source: InventoryState, uid: String, quantity: int, revision: int) -> Error:
	if not point_for.is_valid() or quantity <= 0:
		return ERR_UNAVAILABLE
	var plan := InventoryPlan.new()
	var from := plan.include(source)
	plan.revisions[0] = revision
	var stack := from._by_uid(uid)
	if stack == null or quantity > stack.quantity or not ItemCatalog.resolve(stack.item_id).droppable:
		return ERR_INVALID_DATA
	var bag := prepare(plan,point_for.call(source),source.time_source,"LooseItemDrop")
	if bag == null:
		return plan.error
	var to := plan.include(bag)
	InventoryCommands.place(to,stack.item_id,quantity,StackPolicy.copied_data(stack,from.time_source.now),uid if quantity == stack.quantity else "")
	from.consume_uid(uid,quantity)
	return plan.commit()
func drain_pending(source: InventoryState) -> Error:
	if source._pending.is_empty() or not point_for.is_valid():
		return OK
	var plan := InventoryPlan.new()
	var from := plan.include(source)
	var bag := prepare(plan,point_for.call(source),source.time_source)
	if bag == null:
		return plan.error
	var to := plan.include(bag)
	for index: int in range(from._pending.size()-1,-1,-1):
		var stack := from._pending[index]
		var remainder := InventoryCommands.place(to,stack.item_id,stack.quantity,StackPolicy.copied_data(stack,from.time_source.now),stack.stack_uid)
		if remainder == stack.quantity:
			continue
		if remainder == 0:
			from._pending.remove_at(index)
		else:
			stack.quantity = remainder
			stack.revision += 1
	return plan.commit()
