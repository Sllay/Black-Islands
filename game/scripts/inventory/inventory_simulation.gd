class_name InventorySimulation
extends Node
signal unit_spoiled(source_item_id: String, result_item_id: String)
## One active-time scheduler. No per-stack Node and no per-frame inventory scan.
var clock := GameplayTimeSource.new()
var stores: Array[InventoryState] = []
var deadlines: Dictionary = {}
var pending: Dictionary = {}
var drops: WorldDropService
var checkpoint_container: Callable
var _next := INF
var _checkpoint_at := -1.0
var expirations := 0
var polls := 0
func register(store: InventoryState) -> void:
	if stores.has(store):
		return
	for stack: ItemStack in store._slots+store._pending:
		if stack != null:
			stack.instance_data = StackPolicy.normalize(ItemCatalog.resolve(stack.item_id),StackPolicy.copied_data(stack,store.time_source.now),clock.now)
	store.time_source = clock
	stores.append(store)
	store.changed.connect(_changed.bind(store))
	_changed(0,store)
func _changed(_revision: int, store: InventoryState) -> void:
	var due := INF
	for stack: ItemStack in store._slots+store._pending:
		if stack != null:
			var definition := ItemCatalog.resolve(stack.item_id)
			if not definition.spoilage.is_empty():
				due = minf(due,clock.now+StackPolicy.remaining(stack.instance_data,definition,clock.now))
	if is_finite(due):
		deadlines[store] = due
	else:
		deadlines.erase(store)
	if not store._pending.is_empty():
		pending[store] = true
	else:
		pending.erase(store)
	_retime()
func _retime() -> void:
	_next = INF
	for value: float in deadlines.values():
		_next = minf(_next,value)
func advance(delta: float) -> void:
	clock.advance(delta)
	if clock.now >= _next:
		settle()
func settle(budget: int = 64) -> void:
	if InventoryTransactions.busy:
		return
	var count := 0
	for store: InventoryState in deadlines.keys():
		while count < budget and float(deadlines.get(store,INF)) <= clock.now:
			if _expire(store) != OK:
				break
			count += 1
	polls += 1
func _expire(store: InventoryState) -> Error:
	var plan := InventoryPlan.new()
	var copy := plan.include(store)
	for live: ItemStack in store._slots+store._pending:
		if live == null:
			continue
		var definition := ItemCatalog.resolve(live.item_id)
		if definition.spoilage.is_empty():
			continue
		var remaining := StackPolicy.remaining(live.instance_data,definition,clock.now)
		if remaining > 0:
			continue
		var stack := copy._by_uid(live.stack_uid)
		var was_pending := stack == null
		if was_pending:
			stack = copy._pending[store._pending.find(live)]
			stack.quantity -= 1
			if stack.quantity == 0:
				copy._pending.erase(stack)
		else:
			copy.consume_uid(live.stack_uid,1)
		if stack.quantity > 0:
			stack.instance_data.spoilage = {"remaining":float(definition.spoilage.duration),"started_at":clock.now+remaining}
			stack.revision += 1
		InventoryCommands.output(copy,str(definition.spoilage.result_item_id),1)
		var error := plan.commit()
		if error == OK:
			expirations += 1
			unit_spoiled.emit(live.item_id,str(definition.spoilage.result_item_id))
		return error
	_changed(0,store)
	return ERR_DOES_NOT_EXIST
func checkpoint() -> void:
	settle()
	if _checkpoint_at == clock.now:
		return
	_checkpoint_at = clock.now
	if checkpoint_container.is_valid():
		for store: InventoryState in deadlines:
			checkpoint_container.call(store)
func _process(delta: float) -> void:
	advance(delta)
	if drops != null and not pending.is_empty() and not InventoryTransactions.busy:
		var store: InventoryState = pending.keys()[0]
		drops.drain_pending(store)
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED:
		clock.active = false
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		clock.active = true

var registry: ContainerService
var registered_world: Dictionary = {}
func bind_world(service: ContainerService, point: Callable, presentation: Callable) -> void:
	registry = service
	drops = WorldDropService.new()
	drops.containers = service
	drops.point_for = point
	drops.after_publish = presentation
	service.changed.connect(_world_changed)
	for id: String in service.inventories:
		_world_changed(id)
	checkpoint_container = func(store: InventoryState) -> void:
		if store.owner_scope == "WORLD" and registry.inventories.get(store.inventory_id) == store:
			registry.changed.emit(store.inventory_id)
func _world_changed(id: String) -> void:
	if registry.inventories.has(id):
		var store: InventoryState = registry.inventories[id]
		registered_world[id] = store
		register(store)
	elif registered_world.has(id):
		var store: InventoryState = registered_world[id]
		if store.changed.is_connected(_changed.bind(store)):
			store.changed.disconnect(_changed.bind(store))
		stores.erase(store)
		deadlines.erase(store)
		pending.erase(store)
		registered_world.erase(id)
		_retime()
