class_name ItemStack
extends RefCounted

var stack_uid: String
var item_id: String
var quantity: int
var instance_data: Dictionary
var revision := 0

func _init(id: String, count: int, data: Dictionary = {}, uid: String = "") -> void:
	item_id = id
	quantity = count
	instance_data = data.duplicate(true)
	stack_uid = uid if not uid.is_empty() else "stack_" + Crypto.new().generate_random_bytes(12).hex_encode()

func record() -> Dictionary:
	return {"stack_uid":stack_uid, "item_id":item_id, "quantity":quantity, "instance_data":instance_data.duplicate(true), "revision":revision}
