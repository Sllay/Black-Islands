class_name WorldDropService
extends RefCounted
## Prepared world ownership; no mesh/scene creation in the transaction domain.
var containers: ContainerService
var point_for: Callable
var after_publish: Callable
func prepare(plan: InventoryPlan, point: Vector3, clock: GameplayTimeSource) -> InventoryState:
	if containers == null or not point.is_finite():
		plan.error = ERR_UNAVAILABLE
		return null
	var id := "drop_"+Crypto.new().generate_random_bytes(12).hex_encode()
	var inventory := InventoryState.new()
	inventory.inventory_id = id
	inventory.owner_scope = "WORLD"
	inventory.time_source = clock
	var expected := containers.revision
	var publication := InventoryPublication.new()
	publication.validate = func() -> bool: return containers.revision == expected and not containers.inventories.has(id)
	publication.apply = func() -> void:
		containers.inventories[id] = inventory
		containers.records[id] = {"id":id,"position":[point.x,point.y,point.z],"kind":"WorldDropBag","deadline":-1,"policy":"persistent"}
		containers._index_record(id,point)
		inventory.changed.connect(containers._inventory_changed.bind(id))
		containers.revision += 1
	publication.notify = func() -> void:
		containers.changed.emit(id)
		if after_publish.is_valid():
			after_publish.call()
	plan.publications.append(publication)
	return inventory
func drop(source: InventoryState, uid: String, quantity: int, revision: int) -> Error:
	if not point_for.is_valid() or quantity <= 0:
		return ERR_UNAVAILABLE
	var plan := InventoryPlan.new()
	var from := plan.include(source)
	plan.revisions[0] = revision
	var stack := from._by_uid(uid)
	if stack == null or quantity > stack.quantity or not ItemCatalog.resolve(stack.item_id).droppable:
		return ERR_INVALID_DATA
	var bag := prepare(plan,point_for.call(source),source.time_source)
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
