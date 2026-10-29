class_name ContainerService
extends RefCounted
var inventories: Dictionary = {}
var records: Dictionary = {}

func create(id: String, point: Vector3, kind: String = "Chest") -> InventoryState:
	if inventories.has(id):
		return inventories[id]
	var inventory := InventoryState.new()
	inventory.inventory_id = id
	inventory.owner_scope = "WORLD"
	inventories[id] = inventory
	records[id] = {"id":id,"position":[point.x,point.y,point.z],"kind":kind,"deadline":-1,"policy":"persistent"}
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
	return OK

func transfer_all(source: InventoryState, destination: InventoryState) -> Error:
	var from := InventoryTransactions.clone(source)
	var to := InventoryTransactions.clone(destination)
	for index: int in InventoryState.CAPACITY:
		var row := from.slot_at(index)
		if row.is_empty():
			continue
		if to.add_item(row.item_id,int(row.quantity),row.instance_data) != 0:
			return ERR_OUT_OF_MEMORY
		from.consume_uid(row.stack_uid,int(row.quantity))
	return InventoryTransactions.commit([source,destination],[from,to],[source.revision,destination.revision])
