class_name CraftOutput
extends RefCounted
var item_id: String
var quantity: int
var metadata: Dictionary
func _init(data: Dictionary) -> void:
	item_id = str(data.get("item_id",""))
	quantity = int(data.get("quantity",0))
	metadata = data.get("metadata",{}).duplicate(true)
