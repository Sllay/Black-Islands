extends Node
var failures := 0
var assertions := 0
var _services: Array[CraftService] = []
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("R3_CRAFT "+label)
func store(id: String, wood: int = 0, stone: int = 0) -> InventoryState:
	var result := InventoryState.new()
	result.inventory_id = id
	if wood > 0:
		result.add_item("bi.resource.wood",wood)
	if stone > 0:
		result.add_item("bi.resource.stone",stone)
	return result
func amount(state: InventoryState, id: String) -> int:
	var result := 0
	for stack: ItemStack in state._slots+state._pending:
		if stack != null and stack.item_id == id:
			result += stack.quantity
	return result
func resources(stores: Array[InventoryState], outputs: Array[InventoryState] = []) -> ResourceScope:
	var scope := ResourceScope.new()
	scope.sources = stores
	scope.destinations.assign([stores[0]] if outputs.is_empty() else outputs)
	return scope
func service_for(scope: ResourceScope) -> CraftService:
	var service := CraftService.new()
	_services.append(service)
	service.resolve_scope = func(_context: Dictionary) -> ResourceScope: return scope
	for participant: InventoryState in scope.sources:
		participant.changed.connect(func(_revision: int) -> void: service.invalidate())
	return service
func complete(service: CraftService) -> Error:
	service.queue.elapsed = 100
	return service.request_completion(service.queue.jobs[0])
func _ready() -> void:
	_domain()
	_scope()
	_output()
	_save()
	_performance()
	for service: CraftService in _services:
		var scope := service.scope({})
		if scope != null:
			for participant: InventoryState in scope.sources:
				for connection: Dictionary in participant.changed.get_connections():
					participant.changed.disconnect(connection.callable)
		service.resolve_scope = Callable()
	_services.clear()
	print("R3_CRAFT ","PASS" if failures == 0 else "FAIL"," assertions=",assertions," failures=",failures)
	get_tree().quit(1 if failures else 0)
func _domain() -> void:
	var player := store("player",80,20)
	var service := service_for(resources([player]))
	check(service.catalog.definitions.size() == 5,"valid data-driven recipes")
	check(service.enqueue("bi.recipe.foundation",10) == OK and service.enqueue("bi.recipe.ceiling",10) == OK,"enqueue no reservation")
	check(amount(player,"bi.resource.wood") == 80,"enqueue does not consume")
	service.refresh()
	service.tick(.5)
	check(amount(player,"bi.build.foundation") == 0 and service.queue.elapsed == .5,"timer only head")
	check(complete(service) == OK and amount(player,"bi.build.foundation") == 1,"simple atomic craft")
	var observed := {"consistent":true}
	player.changed.connect(func(_revision: int) -> void:
		if service.queue.jobs[0].requested_remaining != 8:
			observed.consistent = false,CONNECT_ONE_SHOT)
	check(complete(service) == OK and observed.consistent,"queue publication before inventory observers")
	for index: int in 4:
		complete(service)
	service.refresh()
	check(service.queue.jobs[1].requested_remaining == 8,"shared resources shrink future quantity")
	player.add_item("bi.resource.wood",40)
	service.refresh()
	check(service.queue.jobs[1].requested_remaining == 8,"clamp never regrows")
	service.queue.elapsed = 1
	check(service.queue.reorder(service.queue.jobs[1].id,0) == OK and service.queue.elapsed == 0,"reorder resets timer")
	var before := amount(player,"bi.resource.wood")
	check(service.queue.cancel(service.queue.jobs[0].id) == OK and amount(player,"bi.resource.wood") == before,"cancel no refund or consumption")
	while service.queue.jobs.size() < 5:
		service.enqueue("bi.recipe.foundation",1)
	check(service.enqueue("bi.recipe.foundation",1) != OK and service.queue.jobs.size() == 5,"queue cap5")
	var plan := service.completion_plan(service.queue.jobs[0])
	service.queue.cancel(service.queue.jobs[0].id)
	check(plan.commit() == ERR_ALREADY_IN_USE and amount(player,"bi.resource.wood") == before,"cancel invalidates prepared completion")
	var tiny := service_for(resources([store("tiny",8,2)]))
	tiny.enqueue("bi.recipe.foundation",1)
	tiny.enqueue("bi.recipe.ceiling",1)
	complete(tiny)
	tiny.refresh()
	check(tiny.queue.jobs.is_empty(),"impossible job removed without loop")
func _scope() -> void:
	var player := store("player",2)
	var a := store("chest_a",8)
	var b := store("chest_b",0,5)
	var scope := resources([player,a,b])
	var recipe := RecipeDefinition.new({"id":"qa.multi","ingredients":[{"item_id":"bi.resource.wood","quantity":4},{"item_id":"bi.resource.wood","quantity":6},{"item_id":"bi.resource.stone","quantity":5}],"outputs":[{"item_id":"bi.build.foundation","quantity":1}],"craft_duration":1})
	check(recipe.costs()["bi.resource.wood"] == 10,"ingredient aggregation")
	var plan := CraftTransaction.build(recipe,scope)
	a.select_hotbar(1)
	check(plan.commit() == ERR_ALREADY_IN_USE and amount(player,"bi.resource.wood") == 2 and amount(b,"bi.resource.stone") == 5,"stale3participants abort no partial")
	check(CraftTransaction.build(recipe,scope).commit() == OK,"multi container commit")
	check(amount(player,"bi.resource.wood")+amount(a,"bi.resource.wood") == 0 and amount(b,"bi.resource.stone") == 0 and amount(player,"bi.build.foundation") == 1,"multi container conservation")
	player = store("guard",10,5)
	var permitted := {"value":true}
	scope = resources([player])
	scope.validate = func() -> bool: return permitted.value
	plan = CraftTransaction.build(recipe,scope)
	permitted.value = false
	check(plan.commit() == ERR_ALREADY_IN_USE and amount(player,"bi.resource.wood") == 10,"authorization changes reject")
	var registry := ContainerService.new()
	registry.create("near",Vector3(2,0,0))
	registry.create("far",Vector3(100,0,0))
	registry.create("locked",Vector3.ONE)
	registry.records.locked.locked = true
	var resolver := NearbyContainerResolver.new()
	check(resolver.resolve(registry,Vector3.ZERO,12,"player").size() == 1,"spatial authorized nearby only")
func _output() -> void:
	var player := store("full",16,4)
	player._slots[0].quantity = 16
	for index: int in range(2,20):
		player._slots[index] = ItemStack.new("bi.weapon.starter_sword",1)
	var registry := ContainerService.new()
	var drops := WorldDropService.new()
	drops.containers = registry
	drops.point_for = func(_inventory: InventoryState) -> Vector3: return Vector3.ZERO
	var service := service_for(resources([player]))
	service.drops = drops
	service.enqueue("bi.recipe.foundation",1)
	check(complete(service) == OK and registry.inventories.size() == 1,"full output prepared world bag")
	check(amount(registry.inventories.values()[0],"bi.build.foundation") == 1 and amount(player,"bi.resource.wood") == 8,"drop output conserved after payment")
	player = store("pending",16,4)
	for index: int in range(2,20):
		player._slots[index] = ItemStack.new("bi.weapon.starter_sword",1)
	service = service_for(resources([player]))
	service.enqueue("bi.recipe.foundation",1)
	check(complete(service) == OK and player._pending.size() == 1,"no world context retains pending output")
func _save() -> void:
	var queue := CraftQueue.new()
	queue.enqueue("bi.recipe.foundation",5)
	queue.enqueue("bi.recipe.arrows",3,{"world_id":"worldA","station_id":"stationA"})
	queue.elapsed = .75
	var snapshot := JSON.parse_string(JSON.stringify(queue.snapshot())) as Dictionary
	var loaded := CraftQueue.new()
	check(loaded.restore(snapshot) == OK and loaded.jobs.size() == 2 and loaded.jobs[0].requested_remaining == 5,"queue save reload")
	check(loaded.elapsed == 0 and not snapshot.has("elapsed"),"fractional timer not saved")
	check(loaded.jobs[1].context.world_id == "worldA","station world context persists independently")
	check(CraftQueue.new().restore({"schema_version":2}) == ERR_UNAVAILABLE,"future schema reject")
	check(CraftQueue.new().restore({}) == OK,"old player additive empty queue")
func _performance() -> void:
	var player := store("perf",256,256)
	var chest := store("chest",256,256)
	var service := service_for(resources([player,chest]))
	for index: int in 105:
		var recipe := RecipeDefinition.new({"id":"qa.recipe.%d"%index,"ingredients":[{"item_id":"bi.resource.wood","quantity":1}],"outputs":[{"item_id":"bi.ammo.arrow","quantity":1}],"craft_duration":1})
		service.catalog.definitions[recipe.id] = recipe
	for index: int in 5:
		service.enqueue("bi.recipe.foundation",10)
	var start := Time.get_ticks_usec()
	for recipe: RecipeDefinition in service.catalog.definitions.values():
		service.availability(recipe)
	var initial := Time.get_ticks_usec()-start
	var misses := service.cache_misses
	start = Time.get_ticks_usec()
	for repeat: int in 100:
		for recipe: RecipeDefinition in service.catalog.definitions.values():
			service.availability(recipe)
	var cached := Time.get_ticks_usec()-start
	check(service.cache_misses == misses,"110 recipes repeated cached without rescanning stacks")
	print("CRAFT_PERF recipes=",service.catalog.definitions.size()," initial_us=",initial," cached11000_us=",cached," misses=",misses," queue=",service.queue.jobs.size())
