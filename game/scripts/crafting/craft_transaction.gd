class_name CraftTransaction
extends RefCounted
## One unit, every participant cloned/captured before any payment or output.
static func build(recipe: RecipeDefinition, scope: ResourceScope, drops: WorldDropService = null) -> InventoryPlan:
	var plan := InventoryPlan.new()
	if scope == null or not recipe.valid() or not scope.permits(recipe) or scope.sources.is_empty() or scope.destinations.is_empty():
		plan.error = ERR_UNAVAILABLE
		return plan
	var ordered := scope.sources.duplicate()
	ordered.sort_custom(func(a: InventoryState,b: InventoryState) -> bool: return a.inventory_id < b.inventory_id)
	for store: InventoryState in ordered:
		plan.include(store)
	for store: InventoryState in scope.destinations:
		plan.include(store)
	for id: String in recipe.costs():
		var left := int(recipe.costs()[id])
		for store: InventoryState in ordered:
			var copy := plan.include(store)
			for index: int in InventoryState.CAPACITY:
				var stack := copy._slots[index]
				if stack == null or stack.item_id != id:
					continue
				var definition := ItemCatalog.resolve(id)
				if not definition.spoilage.is_empty() and StackPolicy.remaining(stack.instance_data,definition,copy.time_source.now) <= 0:
					continue
				var amount := mini(left,stack.quantity)
				copy.consume_uid(stack.stack_uid,amount)
				left -= amount
				if left == 0:
					break
			if left == 0:
				break
		if left > 0:
			plan.error = ERR_UNAVAILABLE
			return plan
	var overflow: InventoryState = null
	for output: CraftOutput in recipe.outputs:
		var left := output.quantity
		for store: InventoryState in scope.destinations:
			left = InventoryCommands.place(plan.include(store),output.item_id,left,output.metadata)
			if left == 0:
				break
		if left > 0:
			if overflow == null and drops != null and drops.point_for.is_valid():
				overflow = drops.prepare(plan,drops.point_for.call(scope.destinations[0]),scope.destinations[0].time_source)
			if overflow != null:
				InventoryCommands.output(plan.include(overflow),output.item_id,left,output.metadata)
			else:
				# Valid persisted owner even while no world presentation context exists.
				InventoryCommands.output(plan.include(scope.destinations[0]),output.item_id,left,output.metadata)
	if scope.validate.is_valid():
		var guard := InventoryPublication.new()
		guard.validate = scope.validate
		guard.apply = func() -> void: pass
		plan.publications.append(guard)
	return plan
