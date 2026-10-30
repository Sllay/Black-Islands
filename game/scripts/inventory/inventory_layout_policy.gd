class_name InventoryLayoutPolicy
extends RefCounted
## Stable empty slots by default; explicit organize is blocked during dragging.
static var dragging: Dictionary = {}
static func begin(id: String) -> void:
	dragging[id] = int(dragging.get(id,0))+1
static func end(id: String) -> void:
	dragging[id] = maxi(0,int(dragging.get(id,0))-1)
static func compact(store: InventoryState, revision: int) -> Error:
	if dragging.get(store.inventory_id,0) > 0:
		return ERR_BUSY
	var plan := InventoryPlan.new()
	var copy := plan.include(store)
	plan.revisions[0] = revision
	var slots: Array[ItemStack] = []
	for stack: ItemStack in copy._slots:
		if stack != null:
			slots.append(stack)
	slots.resize(InventoryState.CAPACITY)
	copy._slots = slots
	return plan.commit()
