class_name CraftRuntime
extends Node
## One scheduler per character, one head timer, no per-recipe/stack processing.
var component: InventoryComponent
var actor: PlayerActor
var registry: ContainerService
var opened_id := ""
var world_id := ""
var service := CraftService.new()
var nearby := NearbyContainerResolver.new()
var _last_time := 0.0
var _poll := 0.0
var _position := Vector3.INF
func configure(owner_component: InventoryComponent) -> void:
	component = owner_component
	actor = component.get_parent() as PlayerActor
	service.resolve_scope = resolve
	_last_time = component.state.time_source.now
func bind_world(containers: ContainerService, identity: String) -> void:
	registry = containers
	world_id = identity
	service.drops = component.simulation.drops
	registry.changed.connect(func(_id: String) -> void: service.invalidate())
	service.invalidate()
func _ready() -> void:
	component.state.changed.connect(func(_revision: int) -> void: service.invalidate())
func _process(delta: float) -> void:
	var now := component.state.time_source.now
	var step := maxf(0,now-_last_time)
	_last_time = now
	_poll += delta
	if _poll >= .25:
		_poll = 0
		if actor != null and actor.global_position.distance_squared_to(_position) > .25:
			_position = actor.global_position
			service.invalidate()
	service.tick(step)
func open_container(id: String) -> void:
	opened_id = id
	service.invalidate()
func station_context() -> Dictionary:
	return {"station_id":opened_id,"world_id":world_id} if CraftStation.available(registry,opened_id) else {}
func resolve(context: Dictionary) -> ResourceScope:
	var result := _resolve(context)
	if result != null:
		var expected := result.signature()
		result.validate = func() -> bool:
			var fresh := _resolve(context)
			return fresh != null and fresh.signature() == expected
	return result
func _resolve(context: Dictionary) -> ResourceScope:
	var result := ResourceScope.new()
	result.sources = [component.state]
	result.destinations = [component.state]
	if actor == null:
		return result if context.is_empty() else null
	var point := actor.global_position
	var owner := component.state.inventory_id
	if not context.is_empty():
		var id := str(context.get("station_id",""))
		if context.get("world_id") != world_id or not CraftStation.available(registry,id) or not nearby.policy.allows(registry,id,owner,point,4):
			return null
		var station: InventoryState = registry.inventories[id]
		result.sources.append(station)
		result.destinations.append(station)
		result.station_tags = ["workbench"]
		var row: Dictionary = registry.records[id]
		var center := Vector3(row.position[0],row.position[1],row.position[2])
		for store: InventoryState in nearby.resolve(registry,center,service.catalog.nearby_radius,owner):
			result.sources.append(store)
			result.destinations.append(store)
	elif not opened_id.is_empty() and nearby.policy.allows(registry,opened_id,owner,point,4):
		result.sources.append(registry.inventories[opened_id])
		result.destinations.append(registry.inventories[opened_id])
	return result
