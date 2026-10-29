class_name ItemCatalog
extends RefCounted

const VERSION := 1
const DEFINITIONS := [
	{"id":"bi.weapon.starter_sword", "title":"Espada de treino", "category":"WEAPON", "icon":"⚔", "moveset_id":"sword.training.v1", "visual_id":"lpc.weapon.sword"},
	{"id":"bi.tool.stone_pick", "title":"Picareta", "category":"TOOL", "icon":"⛏"},
	{"id":"bi.food.coconut", "title":"Coco", "category":"CONSUMABLE", "icon":"◉", "use_effect":"restore_health", "use_amount":12},
	{"id":"bi.resource.stone", "title":"Pedra", "category":"RESOURCE", "icon":"◆"},
	{"id":"bi.build.foundation", "title":"Fundação", "category":"BUILDING_PIECE", "icon":"▱"},
	{"id":"bi.ammo.arrow", "title":"Flecha", "category":"PROJECTILE", "icon":"➶"},
	{"id":"bi.armor.fiber_hat", "title":"Elmo de fibra", "category":"ARMOR", "icon":"♧", "equipment_slots":["helmet"], "defense":3},
	{"id":"bi.armor.fiber_chest", "title":"Peitoral de fibra", "category":"ARMOR", "icon":"▣", "equipment_slots":["chest"], "defense":8},
	{"id":"bi.armor.fiber_legs", "title":"Calças de fibra", "category":"ARMOR", "icon":"Π", "equipment_slots":["legs"], "defense":5},
	{"id":"bi.accessory.shell_charm", "title":"Amuleto de concha", "category":"ACCESSORY", "icon":"◇", "equipment_slots":["accessory_1","accessory_2"], "defense":1}
]
static var _definitions: Dictionary = {}

static func resolve(id: String) -> ItemDefinition:
	if _definitions.is_empty():
		for record: Dictionary in DEFINITIONS:
			_definitions[record.id] = ItemDefinition.new(record)
	return _definitions.get(id)
