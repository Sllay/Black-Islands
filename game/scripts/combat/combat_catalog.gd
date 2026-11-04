class_name CombatCatalog
extends RefCounted
const VERSION := 1
static var _sword: MovesetDefinition
static var _dodge: DodgeDefinition

static func moveset(id: String) -> MovesetDefinition:
	var record := ContentData.find("movesets",id)
	if record.is_empty() or record.get("template_id") != "sword.training.v1":
		return null
	if _sword == null:
		_sword = load("res://resources/combat/SwordMoveset.tres")
	return _sword

static func dodge() -> DodgeDefinition:
	if _dodge == null:
		_dodge = load("res://resources/combat/Dodge.tres")
	return _dodge
