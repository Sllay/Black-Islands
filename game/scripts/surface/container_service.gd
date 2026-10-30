class_name ContainerService
extends RefCounted
signal changed(id: String)
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
	if not records.has(id) or records[id].kind != "Chest":
		return ERR_ALREADY_IN_USE
	var row: Dictionary = records[id]
	var point := Vector3(row.position[0],row.position[1],row.position[2])
	var bag := create("broken_chest:"+id,point,"WorldDropBag")
	var error := transfer_all(inventories[id],bag)
	if error != OK:
		return error
	records.erase(id)
	inventories.erase(id)
	changed.emit(id)
	return OK

func _inventory_changed(_revision: int, id: String) -> void:
	revision += 1
	changed.emit(id)

func transfer_all(source: InventoryState, destination: InventoryState) -> Error:
	var plan := InventoryPlan.new()
	var from := plan.include(source)
	var to := plan.include(destination)
	for stack: ItemStack in from._slots+from._pending:
		if stack == null:
			continue
		var data := StackPolicy.copied_data(stack,from.time_source.now)
		var remaining := InventoryCommands.place(to,stack.item_id,stack.quantity,data,stack.stack_uid)
		if remaining > 0:
			to._pending.append(ItemStack.new(stack.item_id,remaining,StackPolicy.normalize(ItemCatalog.resolve(stack.item_id),data,to.time_source.now),stack.stack_uid))
		if stack in from._slots:
			from.consume_uid(stack.stack_uid,stack.quantity)
	from._pending.clear()
	return plan.commit()
