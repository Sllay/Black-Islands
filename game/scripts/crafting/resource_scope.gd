class_name ResourceScope
extends RefCounted
## Snapshot of authorized sources. Fresh resolver membership is checked at commit.
var sources: Array[InventoryState] = []
var destinations: Array[InventoryState] = []
var station_tags: Array = []
var validate: Callable
func counts() -> Dictionary:
	var result := {}
	for store: InventoryState in sources:
		for stack: ItemStack in store._slots:
			if stack != null:
				var definition := ItemCatalog.resolve(stack.item_id)
				if not definition.spoilage.is_empty() and StackPolicy.remaining(stack.instance_data,definition,store.time_source.now) <= 0:
					continue
				result[stack.item_id] = int(result.get(stack.item_id,0))+stack.quantity
	return result
func signature() -> String:
	var keys: Array[String] = []
	for store: InventoryState in sources+destinations:
		keys.append(store.inventory_id+":"+str(store.revision))
	return "|".join(keys)+str(station_tags)
func permits(recipe: RecipeDefinition) -> bool:
	for tag: String in recipe.station_tags:
		if tag not in station_tags:
			return false
	return true
