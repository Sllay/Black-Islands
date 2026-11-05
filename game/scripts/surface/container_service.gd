class_name ContainerService
extends RefCounted
signal changed(id: String)
signal open_state_changed(id: String, open: bool)
var open_sessions: Dictionary = {}
var access_policy := ContainerAccessPolicy.new()
# Bound to WorldSave flags; survives looting/removal of the published bag.
var completed_events: Dictionary = {}
var inventories: Dictionary = {}
var revision := 0
var records: Dictionary = {}

func create(id: String, point: Vector3, kind: String = "Chest") -> InventoryState:
	if inventories.has(id):
		return inventories[id]
	var inventory := InventoryState.new()
	inventory.inventory_id = id
	inventory.owner_scope = "WORLD"
	inventories[id] = inventory
	records[id] = {"id":id,"position":[point.x,point.y,point.z],"kind":kind,"deadline":-1,"policy":"persistent"}
	_index_record(id,point)
	inventory.changed.connect(_inventory_changed.bind(id))
	revision += 1
	changed.emit(id)
	return inventory

func snapshot() -> Dictionary:
	var data := records.duplicate(true)
	for id: String in data:
		data[id].inventory = inventories[id].snapshot()
	return data

func restore(data: Dictionary) -> Error:
	for id: String in data:
		var row: Dictionary = data[id]
		if row.get("id") != id or not row.get("position") is Array or row.position.size() != 3 or not row.get("inventory") is Dictionary:
			return ERR_INVALID_DATA
		var inventory := InventoryState.new()
		if inventory.restore(row.inventory) != OK:
			return ERR_INVALID_DATA
		inventory.inventory_id = id
		inventory.owner_scope = "WORLD"
		inventories[id] = inventory
		records[id] = row.duplicate(true)
		if not str(row.get("event_id","")).is_empty(): completed_events[row.event_id] = id
		_index_record(id,Vector3(row.position[0],row.position[1],row.position[2]))
		inventory.changed.connect(_inventory_changed.bind(id))
	return OK

var _regions: Dictionary = {}

func _index_record(id: String, point: Vector3) -> void:
	var key := Vector3i((point/64.0).floor())
	if not _regions.has(key):
		_regions[key] = []
	if id not in _regions[key]:
		_regions[key].append(id)

func in_area(area: AABB) -> Array[String]:
	var result: Array[String] = []
	var start := Vector3i((area.position/64.0).floor())
	var end := Vector3i((area.end/64.0).floor())
	for y: int in range(start.y,end.y+1):
		for z: int in range(start.z,end.z+1):
			for x: int in range(start.x,end.x+1):
				for id: String in _regions.get(Vector3i(x,y,z),[]):
					if records.has(id):
						var p: Array = records[id].position
						if area.has_point(Vector3(p[0],p[1],p[2])):
							result.append(id)
	return result

func break_chest(id: String) -> Error:
	if not records.has(id) or records[id].kind not in ["Chest","Workbench"]: return ERR_ALREADY_IN_USE
	var row: Dictionary = records[id]
	var drops := WorldDropService.new()
	drops.containers = self
	return drops.publish_all(inventories[id],Vector3(row.position[0],row.position[1],row.position[2]),"chest_break:"+id,"WorldDropBag","broken_chest:"+id,true)

func _inventory_changed(_revision: int, id: String) -> void:
	revision += 1
	changed.emit(id)

func request_open(id: String, actor_id: String, point: Vector3) -> Error:
	if actor_id.is_empty() or not access_policy.allows(self,id,actor_id,point,4): return ERR_UNAUTHORIZED
	if records[id].kind == "LooseItemDrop": return ERR_UNAVAILABLE
	request_close(actor_id)
	open_sessions[actor_id] = id
	open_state_changed.emit(id,true)
	return OK

func request_close(actor_id: String) -> void:
	var id := str(open_sessions.get(actor_id,""))
	open_sessions.erase(actor_id)
	if not id.is_empty(): open_state_changed.emit(id,is_open(id))

func is_open(id: String) -> bool:
	return id in open_sessions.values()

func retire(id: String) -> void:
	for actor_id: String in open_sessions.keys():
		if open_sessions[actor_id] == id: request_close(actor_id)
	if records.has(id):
		var point: Array = records[id].position
		var region := Vector3i((Vector3(point[0],point[1],point[2])/64.0).floor())
		if _regions.has(region):
			_regions[region].erase(id)
			if _regions[region].is_empty(): _regions.erase(region)
	records.erase(id)
	inventories.erase(id)
	revision += 1

func stage_transfer_all(plan: InventoryPlan, source: InventoryState, destination: InventoryState) -> void:
	var from := plan.include(source)
	var to := plan.include(destination)
	for stack: ItemStack in from._slots+from._pending:
		if stack == null: continue
		var data := StackPolicy.copied_data(stack,from.time_source.now)
		var remaining := InventoryCommands.place(to,stack.item_id,stack.quantity,data,stack.stack_uid)
		if remaining > 0:
			to._pending.append(ItemStack.new(stack.item_id,remaining,StackPolicy.normalize(ItemCatalog.resolve(stack.item_id),data,to.time_source.now),stack.stack_uid))
		if stack in from._slots: from.consume_uid(stack.stack_uid,stack.quantity)
	from._pending.clear()

func transfer_all(source: InventoryState, destination: InventoryState) -> Error:
	var plan := InventoryPlan.new()
	stage_transfer_all(plan,source,destination)
	return plan.commit()
