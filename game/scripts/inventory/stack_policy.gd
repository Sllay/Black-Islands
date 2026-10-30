class_name StackPolicy
extends RefCounted
## Destination owns merged freshness; other metadata must be compatible.
static func normalize(definition: ItemDefinition, data: Dictionary, now: float) -> Dictionary:
	var result := data.duplicate(true)
	if not definition.spoilage.is_empty():
		var module: Dictionary = result.get("spoilage",{})
		module = module.duplicate(true)
		module.remaining = float(module.get("remaining",definition.spoilage.duration))-maxf(0,now-float(module.get("started_at",now)))
		module.started_at = now
		result.spoilage = module
	return result
static func remaining(data: Dictionary, definition: ItemDefinition, now: float) -> float:
	if definition.spoilage.is_empty():
		return INF
	var module: Dictionary = data.get("spoilage",{})
	return float(module.get("remaining",definition.spoilage.duration))-(now-float(module.get("started_at",now)))
static func copied_data(stack: ItemStack, now: float) -> Dictionary:
	var data := stack.instance_data.duplicate(true)
	var definition := ItemCatalog.resolve(stack.item_id)
	if not definition.spoilage.is_empty():
		data.spoilage = {"remaining":remaining(data,definition,now)}
	return data
static func compatible(id: String, destination: Dictionary, source: Dictionary) -> bool:
	var a := destination.duplicate(true)
	var b := source.duplicate(true)
	if not ItemCatalog.resolve(id).spoilage.is_empty():
		a.erase("spoilage")
		b.erase("spoilage")
	return AtomicDocument.same_value(a,b)
static func freshness(row: Dictionary, now: float) -> float:
	if row.is_empty():
		return 1
	var definition := ItemCatalog.resolve(row.item_id)
	if definition.spoilage.is_empty():
		return 1
	return clampf(remaining(row.instance_data,definition,now)/float(definition.spoilage.duration),0,1)
static func valid(definition: ItemDefinition, data: Dictionary) -> bool:
	if data.has("spoilage"):
		if definition.spoilage.is_empty() or not data.spoilage is Dictionary:
			return false
		var value: Variant = data.spoilage.get("remaining")
		if not (value is int or value is float) or not is_finite(value) or value > float(definition.spoilage.duration):
			return false
	return true
