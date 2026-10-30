class_name CraftIngredient
extends RefCounted
var item_id: String
var quantity: int
var tags: Array = [] # Future selector seam; Chapter1 recipes use exact stable IDs.
func _init(data: Dictionary) -> void:
	item_id = str(data.get("item_id",""))
	quantity = int(data.get("quantity",0))
