class_name RecipeDefinition
extends RefCounted
var id: String
var title: String
var icon: String
var ingredients: Array[CraftIngredient] = []
var outputs: Array[CraftOutput] = []
var duration: float
var station_tags: Array
var unlock_tags: Array
func _init(data: Dictionary) -> void:
	id = str(data.get("id",""))
	title = str(data.get("name",id))
	icon = str(data.get("icon","◆"))
	duration = float(data.get("craft_duration",1))
	station_tags = data.get("station_requirements",[])
	unlock_tags = data.get("unlock_tags",[])
	for row: Dictionary in data.get("ingredients",[]):
		ingredients.append(CraftIngredient.new(row))
	for row: Dictionary in data.get("outputs",[]):
		outputs.append(CraftOutput.new(row))
func costs() -> Dictionary:
	var result := {}
	for part: CraftIngredient in ingredients:
		result[part.item_id] = int(result.get(part.item_id,0))+part.quantity
	return result
func valid() -> bool:
	if id.is_empty() or duration <= 0 or not is_finite(duration) or ingredients.is_empty() or outputs.is_empty():
		return false
	for part: CraftIngredient in ingredients:
		if part.quantity <= 0 or ItemCatalog.resolve(part.item_id) == null:
			return false
	for part: CraftOutput in outputs:
		if part.quantity <= 0 or ItemCatalog.resolve(part.item_id) == null:
			return false
	return true
