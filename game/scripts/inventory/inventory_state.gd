class_name InventoryState
extends RefCounted
## Serialized single-owner mutation boundary. Hotbar/equipment reference owned
## stack IDs; they do not clone inventory contents. Multi-store planning is P04.

signal changed(revision: int)
const CAPACITY := 20
const HOTBAR_SIZE := 8
const EQUIPMENT := ["helmet", "chest", "legs", "accessory_1", "accessory_2"]
var inventory_id := "player.inventory"
var revision := 0
var selected := 0
var wallet := {"bi.currency.coins": 0}
var _slots: Array[ItemStack] = []
var _hotbar: Array[String] = []
var _equipment: Dictionary = {}

func _init() -> void:
	_slots.resize(CAPACITY)
	_hotbar.resize(HOTBAR_SIZE)
	_hotbar.fill("")
	for slot: String in EQUIPMENT:
		_equipment[slot] = ""

func slot_at(index: int) -> Dictionary:
	return _slots[index].record() if index >= 0 and index < CAPACITY and _slots[index] != null else {}

func hotbar_at(index: int) -> Dictionary:
	return _by_uid(_hotbar[index]).record() if index >= 0 and index < HOTBAR_SIZE and _by_uid(_hotbar[index]) != null else {}

func equipment_at(slot: String) -> Dictionary:
	var stack := _by_uid(_equipment.get(slot, ""))
	return stack.record() if stack != null else {}

func _by_uid(uid: String) -> ItemStack:
	if uid.is_empty():
		return null
	for stack: ItemStack in _slots:
		if stack != null and stack.stack_uid == uid:
			return stack
	return null

func add_item(id: String, count: int, data: Dictionary = {}) -> int:
	var definition := ItemCatalog.resolve(id)
	if definition == null or count <= 0:
		return maxi(0, count)
	var remaining := count
	for stack: ItemStack in _slots:
		if stack != null and stack.item_id == id and stack.instance_data == data and stack.quantity < definition.max_stack:
			var amount := mini(remaining, definition.max_stack - stack.quantity)
			stack.quantity += amount
			stack.revision += 1
			remaining -= amount
			if remaining == 0:
				break
	for index: int in range(CAPACITY):
		if remaining == 0:
			break
		if _slots[index] == null:
			var amount := mini(remaining, definition.max_stack)
			_slots[index] = ItemStack.new(id, amount, data)
			remaining -= amount
	if remaining != count:
		_commit()
	return remaining

func consume_uid(uid: String, count: int) -> Error:
	var stack := _by_uid(uid)
	if stack == null or count <= 0 or stack.quantity < count:
		return ERR_INVALID_PARAMETER
	stack.quantity -= count
	stack.revision += 1
	if stack.quantity == 0:
		for index: int in range(CAPACITY):
			if _slots[index] == stack:
				_slots[index] = null
		for index: int in range(HOTBAR_SIZE):
			if _hotbar[index] == uid:
				_hotbar[index] = ""
		for slot: String in EQUIPMENT:
			if _equipment[slot] == uid:
				_equipment[slot] = ""
	_commit()
	return OK

func assign_hotbar(index: int, inventory_slot: int) -> Error:
	if index < 0 or index >= HOTBAR_SIZE or inventory_slot < -1 or inventory_slot >= CAPACITY:
		return ERR_INVALID_PARAMETER
	var stack: ItemStack = _slots[inventory_slot] if inventory_slot >= 0 else null
	if stack != null and not ItemCatalog.resolve(stack.item_id).hotbar_allowed():
		return ERR_INVALID_DATA
	_hotbar[index] = stack.stack_uid if stack != null else ""
	_commit()
	return OK

func select_hotbar(index: int) -> Error:
	if index < 0 or index >= HOTBAR_SIZE:
		return ERR_INVALID_PARAMETER
	if selected != index:
		selected = index
		_commit()
	return OK

func equip(slot: String, inventory_slot: int) -> Error:
	if slot not in EQUIPMENT or inventory_slot < -1 or inventory_slot >= CAPACITY:
		return ERR_INVALID_PARAMETER
	var stack: ItemStack = _slots[inventory_slot] if inventory_slot >= 0 else null
	if stack != null:
		var definition := ItemCatalog.resolve(stack.item_id)
		if slot not in definition.equipment_slots:
			return ERR_INVALID_DATA
		if _equipment.values().has(stack.stack_uid):
			return ERR_ALREADY_IN_USE
	_equipment[slot] = stack.stack_uid if stack != null else ""
	_commit()
	return OK

func active_definition() -> ItemDefinition:
	var record := hotbar_at(selected)
	return ItemCatalog.resolve(record.item_id) if not record.is_empty() else null

func equipment_defense() -> float:
	var total := 0.0
	for slot: String in EQUIPMENT:
		var stack := _by_uid(_equipment[slot])
		if stack != null:
			total += ItemCatalog.resolve(stack.item_id).defense
	return total

func snapshot() -> Dictionary:
	var slots: Array = []
	for stack: ItemStack in _slots:
		if stack != null:
			slots.append(stack.record())
		else:
			slots.append(null)
	return {"schema_version":1, "catalog_version":ItemCatalog.VERSION, "inventory_id":inventory_id,
		"owner_scope":"PLAYER", "revision":revision, "slots":slots, "hotbar":_hotbar.duplicate(),
		"equipment":_equipment.duplicate(), "selected":selected, "wallet":wallet.duplicate()}

func restore(data: Dictionary) -> Error:
	if data.get("schema_version") != 1 or data.get("catalog_version") != ItemCatalog.VERSION:
		return ERR_UNAVAILABLE
	if not data.get("slots") is Array or data.slots.size() != CAPACITY or not data.get("hotbar") is Array or data.hotbar.size() != HOTBAR_SIZE or not data.get("equipment") is Dictionary:
		return ERR_INVALID_DATA
	var candidate := InventoryState.new()
	var ids: Dictionary = {}
	for index: int in range(CAPACITY):
		var row: Variant = data.slots[index]
		if row == null:
			continue
		if not row is Dictionary or not row.get("item_id") is String or not row.get("stack_uid") is String or row.stack_uid.is_empty() or ids.has(row.stack_uid):
			return ERR_INVALID_DATA
		var definition := ItemCatalog.resolve(row.item_id)
		var count: Variant = row.get("quantity")
		if definition == null or not (count is float or count is int) or count < 1 or count > definition.max_stack or count != int(count) or not row.get("instance_data", {}) is Dictionary:
			return ERR_INVALID_DATA
		candidate._slots[index] = ItemStack.new(row.item_id, int(count), row.get("instance_data", {}), row.stack_uid)
		ids[row.stack_uid] = true
	for index: int in range(HOTBAR_SIZE):
		var uid: Variant = data.hotbar[index]
		if not uid is String:
			return ERR_INVALID_DATA
		var stack := candidate._by_uid(uid)
		if not uid.is_empty() and (stack == null or not ItemCatalog.resolve(stack.item_id).hotbar_allowed()):
			return ERR_INVALID_DATA
		candidate._hotbar[index] = uid
	var equipped: Dictionary = {}
	for slot: String in EQUIPMENT:
		var uid: Variant = data.equipment.get(slot, "")
		if not uid is String:
			return ERR_INVALID_DATA
		var stack := candidate._by_uid(uid)
		if not uid.is_empty() and (stack == null or slot not in ItemCatalog.resolve(stack.item_id).equipment_slots or equipped.has(uid)):
			return ERR_INVALID_DATA
		if not uid.is_empty():
			equipped[uid] = true
		candidate._equipment[slot] = uid
	var selection: Variant = data.get("selected", 0)
	if not (selection is int or selection is float) or selection < 0 or selection >= HOTBAR_SIZE or selection != int(selection):
		return ERR_INVALID_DATA
	var saved_wallet: Variant = data.get("wallet", {})
	if not saved_wallet is Dictionary:
		return ERR_INVALID_DATA
	var coins: Variant = saved_wallet.get("bi.currency.coins", 0)
	if not (coins is int or coins is float) or coins < 0 or coins > 2147483647 or coins != int(coins):
		return ERR_INVALID_DATA
	_slots = candidate._slots
	_hotbar = candidate._hotbar
	_equipment = candidate._equipment
	selected = int(selection)
	wallet = {"bi.currency.coins":int(coins)}
	_commit()
	return OK

func _commit() -> void:
	revision += 1
	changed.emit(revision)
