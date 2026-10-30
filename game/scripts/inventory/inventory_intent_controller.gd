class_name InventoryIntentController
extends RefCounted
signal feedback(text: String)
var component: InventoryComponent
var actor: PlayerActor
var registry: ContainerService
var paired: InventoryState
var access := ContainerAccessPolicy.new()
var reach := 4.0
func configure(owner_component: InventoryComponent) -> void:
	component = owner_component
	actor = component.get_parent() as PlayerActor
func allowed(store: InventoryState) -> bool:
	if store == component.state:
		return true
	return store == paired and actor != null and access.allows(registry,store.inventory_id,component.state.inventory_id,actor.global_position,reach)
func guard(plan: InventoryPlan) -> void:
	var participants := plan.stores.duplicate()
	var publication := InventoryPublication.new()
	publication.validate = func() -> bool:
		for store: InventoryState in participants:
			if not allowed(store):
				return false
		return true
	publication.apply = func() -> void: pass
	plan.publications.append(publication)
func transfer(source: InventoryState, target: InventoryState, uid: String, quantity: int, source_revision: int, target_revision: int, partial: bool = false) -> Error:
	var plan := InventoryCommands.transfer_plan(source,target,uid,quantity,source_revision,target_revision,partial)
	guard(plan)
	var error := plan.commit()
	feedback.emit("%d transferidos."%plan.amount if error == OK else "Inventário mudou ou destino indisponível. Tente novamente.")
	return error
func consume(source: InventoryState, uid: String, revision: int) -> Error:
	var plan := InventoryPlan.new()
	var copy := plan.include(source)
	plan.revisions[0] = revision
	var stack := copy._by_uid(uid)
	if stack == null or actor == null:
		return ERR_INVALID_DATA
	var definition := ItemCatalog.resolve(stack.item_id)
	if definition.use_effect != "restore_health" or (not definition.spoilage.is_empty() and StackPolicy.remaining(stack.instance_data,definition,copy.time_source.now) <= 0):
		return ERR_UNAVAILABLE
	var previous := actor.state.current_health
	var effect := InventoryPublication.new()
	effect.validate = func() -> bool: return is_instance_valid(actor) and actor.state.current_health == previous
	effect.apply = func() -> void: actor.state.set_health(previous+definition.use_amount)
	plan.publications.append(effect)
	copy.consume_uid(uid,1)
	guard(plan)
	return plan.commit()
func drop(source: InventoryState, uid: String, quantity: int, revision: int) -> Error:
	if not allowed(source) or component.simulation == null or component.simulation.drops == null:
		return ERR_UNAVAILABLE
	return component.simulation.drops.drop(source,uid,quantity,revision)

func reorganize(source: InventoryState, uid: String, target: int, revision: int) -> Error:
	return InventoryCommands.reorganize(source,uid,target,revision) if allowed(source) else ERR_UNAUTHORIZED
func split(source: InventoryState, uid: String, mode: String, revision: int) -> Error:
	return InventoryCommands.split(source,uid,mode,revision) if allowed(source) else ERR_UNAUTHORIZED
func assign(source: InventoryState, uid: String, target: int, equipment: String, revision: int) -> Error:
	if source != component.state or source.revision != revision:
		return ERR_ALREADY_IN_USE
	return InventoryCommands.assign(source,uid,target,equipment)
func unassign(source: InventoryState, target: int, equipment: String, revision: int) -> Error:
	if source != component.state:
		return ERR_UNAUTHORIZED
	var plan := InventoryPlan.new()
	var copy := plan.include(source)
	plan.revisions[0] = revision
	if equipment.is_empty():
		copy.assign_hotbar(target,-1)
	else:
		copy.equip(equipment,-1)
	return plan.commit()
func organize() -> Error:
	return InventoryLayoutPolicy.compact(component.state,component.state.revision)
func can_consume(row: Dictionary) -> bool:
	return not row.is_empty() and ItemCatalog.resolve(row.item_id).use_effect == "restore_health"
