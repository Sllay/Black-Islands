class_name NearbyContainerResolver
extends RefCounted
var policy := ContainerAccessPolicy.new()
func resolve(registry: ContainerService, point: Vector3, radius: float, actor_id: String) -> Array[InventoryState]:
	var result: Array[InventoryState] = []
	if registry == null:
		return result
	var ids := registry.in_area(AABB(point-Vector3.ONE*radius,Vector3.ONE*radius*2))
	ids.sort()
	for id: String in ids:
		if registry.records[id].kind == "Chest" and policy.allows(registry,id,actor_id,point,radius):
			result.append(registry.inventories[id])
	return result
