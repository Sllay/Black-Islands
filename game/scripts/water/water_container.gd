class_name WaterContainer
extends RefCounted
## Finite instance module; keeps identity/revision and participates in existing save.
static func volume(inventory: InventoryState, uid: String) -> float:
	return float(inventory.record_by_uid(uid).get("instance_data",{}).get("water_volume",0))
static func change(inventory: InventoryState, uid: String, value: float) -> Error:
	var stack := inventory._by_uid(uid)
	if stack == null or stack.item_id != "bi.tool.watering_can" or not is_finite(value):
		return ERR_INVALID_DATA
	var tuning: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/water/tuning.json"))
	stack.instance_data.water_volume = clampf(value,0,tuning.can_capacity)
	stack.instance_data.water_capacity = float(tuning.can_capacity)
	stack.revision += 1
	inventory._commit()
	return OK
static func refill(inventory: InventoryState, uid: String, facade: WorldWater, point: Vector3, actor_point: Vector3) -> Error:
	if actor_point.distance_to(point) > float(facade.motion_tuning.refill_distance):
		return ERR_UNAUTHORIZED
	var sample := facade.sample(point)
	if sample.kind not in ["lake","river"] or sample.depth < .05:
		return ERR_UNAVAILABLE
	var tuning: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/water/tuning.json"))
	return change(inventory,uid,float(tuning.can_capacity))
static func water_plot(inventory: InventoryState, uid: String, farms: FarmSystem, key: String) -> Error:
	var cost := float(JSON.parse_string(FileAccess.get_file_as_string("res://data/water/tuning.json")).watering_cost)
	if not farms.plots.has(key) or volume(inventory,uid) < cost:
		return ERR_UNAVAILABLE
	var error := farms.water(key)
	if error == OK:
		return change(inventory,uid,volume(inventory,uid)-cost)
	return error
