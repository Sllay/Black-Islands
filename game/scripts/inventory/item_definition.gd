class_name ItemDefinition
extends RefCounted
## Immutable catalog data. Legacy fields remain adapters; saves own only IDs/state.
const STACK_LIMITS := {"RESOURCE":256,"CONSUMABLE":32,"TOOL":1,"WEAPON":1,"ARMOR":1,"ACCESSORY":1,"BUILDING_PIECE":12,"PROJECTILE":999}
const HOTBAR_CATEGORIES := ["WEAPON","TOOL","CONSUMABLE","BUILDING_PIECE"]
var id: String
var title: String
var name_key: String
var description_key: String
var description: String
var category: String
var icon: String
var max_stack: int
var world_visual_id: String
var tags: Array
var modules: Array
var equipment_slots: Array
var defense: float
var moveset_id: String
var visual_id: String
var spoilage: Dictionary = {}
var droppable := true
var use_effect: String
var use_amount: float
func _init(record: Dictionary) -> void:
	id = record.id
	name_key = record.get("name_key","")
	description_key = record.get("description_key","")
	title = _localized(name_key,record.get("title",id))
	description = _localized(description_key,record.get("description",""))
	category = record.category
	icon = record.get("icon","•")
	max_stack = int(record.get("stack_limit",record.get("max_stack",STACK_LIMITS.get(category,1))))
	world_visual_id = record.get("world_visual_id","")
	tags = record.get("tags",[]).duplicate()
	modules = record.get("modules",[]).duplicate(true)
	equipment_slots = record.get("equipment_slots",[])
	defense = float(record.get("defense",0))
	moveset_id = record.get("moveset_id","")
	visual_id = record.get("visual_id","")
	spoilage = record.get("spoilage",{}).duplicate(true)
	droppable = bool(record.get("droppable",true))
	use_effect = record.get("use_effect","")
	use_amount = float(record.get("use_amount",0))
	var spoil := module("SpoilageModule")
	if not spoil.is_empty():
		spoilage = {"duration":spoil.duration,"result_item_id":spoil.result_item_id}
	var consume := module("ConsumableModule")
	if not consume.is_empty():
		use_effect = consume.get("legacy_effect",use_effect)
		use_amount = float(consume.get("amount",use_amount))
func module(type: String) -> Dictionary:
	for row: Dictionary in modules:
		if row.get("type") == type: return row
	return {}
func hotbar_allowed() -> bool:
	return category in HOTBAR_CATEGORIES
func category_title() -> String:
	return {"RESOURCE":"Recurso","CONSUMABLE":"Alimento","TOOL":"Ferramenta","WEAPON":"Arma","ARMOR":"Armadura","ACCESSORY":"Acessório","BUILDING_PIECE":"Construção","PROJECTILE":"Munição"}.get(category,"Item")
func _localized(key: String, fallback: String) -> String:
	var translated := str(TranslationServer.translate(key)) if not key.is_empty() else ""
	return translated if not translated.is_empty() and translated != key else fallback
