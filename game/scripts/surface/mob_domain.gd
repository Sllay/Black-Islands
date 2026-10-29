class_name MobDomain
extends RefCounted
signal changed(id: String)
## Shared living/corpse authority. Views/AI paths are never serialized.
var states: Dictionary = {}
var ledger: SurfaceLedger
var containers: ContainerService
var last_conversion := ""

func _init(world_ledger: SurfaceLedger, inventory_service: ContainerService) -> void:
	ledger = world_ledger
	containers = inventory_service

func spawn(id: String, definition: String, point: Vector3) -> Error:
	if states.has(id) or not SurfaceCatalog.data().mobs.has(definition) or not point.is_finite():
		return ERR_INVALID_PARAMETER
	var data: Dictionary = SurfaceCatalog.data().mobs[definition]
	states[id] = {"id":id,"definition":definition,"position":[point.x,point.y,point.z],"health":data.health,
		"life":"ALIVE","attacked_until":0.0,"death_until":0.0,"decompose_at":0.0,
		"harvest":{},"corpse_inventory":"","converted_bag":"","warning_since":-1.0,"intent":"WANDER"}
	changed.emit(id)
	return OK

func hit(id: String, payload: HitPayload) -> float:
	if not states.has(id) or states[id].life != "ALIVE":
		return 0
	var state: Dictionary = states[id]
	var definition: Dictionary = SurfaceCatalog.data().mobs[state.definition]
	var damage := DamageFormula.taken(payload.raw_damage,float(definition.defense))
	state.health = maxf(0,float(state.health)-damage)
	state.attacked_until = ledger.clock+8
	if state.health <= 0:
		state.life = "DEATH"
		state.death_until = ledger.clock+.3
	changed.emit(id)
	return damage

func evaluate() -> void:
	for id: String in states:
		var state: Dictionary = states[id]
		var definition: Dictionary = SurfaceCatalog.data().mobs[state.definition]
		if state.life == "DEATH" and ledger.clock >= state.death_until:
			var container_id := "corpse:"+id
			var inventory := containers.create(container_id,_point(state),"Corpse")
			if InventoryTransactions.output(inventory,definition.delicate).error != OK:
				continue
			state.corpse_inventory = container_id
			state.harvest = HarvestService.create(definition.harvest)
			state.decompose_at = ledger.clock+float(definition.decomposition)
			state.life = "CORPSE"
			changed.emit(id)
		if state.life == "CORPSE" and (ledger.clock >= state.decompose_at or float(state.harvest.health) <= 0):
			decompose(id)

func harvest(id: String, tool: String, command: String, revision: int, player_inventory: InventoryState) -> Dictionary:
	if not states.has(id) or states[id].life != "CORPSE" or not SurfaceCatalog.data().tools.has(tool):
		return {"error":ERR_INVALID_DATA}
	var state: Dictionary = states[id]
	var result := HarvestService.strike(state.harvest,SurfaceCatalog.data().tools[tool],revision,command)
	if result.error != OK:
		return result
	var output := InventoryTransactions.output(player_inventory,result.outputs)
	if output.error != OK:
		return output
	state.harvest = result.state
	changed.emit(id)
	result.overflow = output.overflow
	return result

func decompose(id: String) -> Error:
	if not states.has(id) or states[id].life != "CORPSE":
		return ERR_ALREADY_IN_USE
	var state: Dictionary = states[id]
	var definition: Dictionary = SurfaceCatalog.data().mobs[state.definition]
	var source: InventoryState = containers.inventories[state.corpse_inventory]
	if definition.protected_loot:
		var bag_id := "deathbag:"+id
		var bag := containers.create(bag_id,_point(state),"DeathBagInventory")
		var error := containers.transfer_all(source,bag)
		if error != OK:
			return error
		state.converted_bag = bag_id
		last_conversion = bag_id
	else:
		var discard := InventoryState.new()
		discard.inventory_id = "discard:"+id
		var error := containers.transfer_all(source,discard)
		if error != OK:
			return error # Defined passive delicate-loot loss, not a world item copy.
	containers.records.erase(state.corpse_inventory)
	containers.inventories.erase(state.corpse_inventory)
	containers.changed.emit(state.corpse_inventory)
	state.life = "REMOVED"
	changed.emit(id)
	return OK

func pack_player_death(source: InventoryState, point: Vector3, id: String) -> Error:
	var bag := containers.create("player_death:"+id,point,"DeathBagInventory")
	return containers.transfer_all(source,bag)

static func _point(state: Dictionary) -> Vector3:
	return Vector3(state.position[0],state.position[1],state.position[2])
