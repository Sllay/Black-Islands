class_name ItemDefinition
extends RefCounted
## Immutable catalog definition, never a mutable owned stack.

const STACK_LIMITS := {"RESOURCE":256, "CONSUMABLE":32, "TOOL":1, "WEAPON":1, "ARMOR":1, "ACCESSORY":1, "BUILDING_PIECE":12, "PROJECTILE":999}
const HOTBAR_CATEGORIES := ["WEAPON", "TOOL", "CONSUMABLE", "BUILDING_PIECE"]
var id: String
var title: String
var category: String
var icon: String
var max_stack: int
var equipment_slots: Array
var defense: float
var moveset_id: String
var visual_id: String
var spoilage: Dictionary = {}
var description: String
var droppable := true
var use_effect: String
var use_amount: float

func _init(record: Dictionary) -> void:
	id = record.id
	title = record.title
	category = record.category
	icon = record.get("icon", "•")
	max_stack = int(record.get("max_stack", STACK_LIMITS.get(category, 1)))
	equipment_slots = record.get("equipment_slots", [])
	defense = float(record.get("defense", 0))
	moveset_id = record.get("moveset_id", "")
	visual_id = record.get("visual_id", "")
	spoilage = record.get("spoilage",{}).duplicate(true)
	description = record.get("description","")
	droppable = bool(record.get("droppable",true))
	use_effect = record.get("use_effect", "")
	use_amount = float(record.get("use_amount", 0))

func hotbar_allowed() -> bool:
	return category in HOTBAR_CATEGORIES

func category_title() -> String:
	return {"RESOURCE":"Recurso", "CONSUMABLE":"Alimento", "TOOL":"Ferramenta", "WEAPON":"Arma", "ARMOR":"Armadura", "ACCESSORY":"Acessório", "BUILDING_PIECE":"Construção", "PROJECTILE":"Munição"}.get(category, "Item")
