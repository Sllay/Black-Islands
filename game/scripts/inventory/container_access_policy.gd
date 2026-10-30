class_name ContainerAccessPolicy
extends RefCounted
## Authorization seam. Chapter1 public/owner data, replaceable for tribes/server.
var authorize: Callable
func allows(registry: ContainerService, id: String, actor_id: String, point: Vector3, radius: float) -> bool:
	if registry == null or not registry.inventories.has(id) or not registry.records.has(id):
		return false
	var row: Dictionary = registry.records[id]
	if row.get("locked",false) or not row.get("available",true):
		return false
	var where := Vector3(row.position[0],row.position[1],row.position[2])
	if where.distance_to(point) > radius:
		return false
	if authorize.is_valid():
		return bool(authorize.call(row,actor_id))
	return row.get("owner_id","") in ["",actor_id] or row.get("access","") == "public"
