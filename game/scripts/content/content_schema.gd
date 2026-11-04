@tool
class_name ContentSchema
extends RefCounted
const CATEGORIES := ["RESOURCE","CONSUMABLE","WEAPON","TOOL","ARMOR","ACCESSORY","BUILDING_PIECE","PROJECTILE"]
const MODULES := {
 "ConsumableModule":{"effects":[],"legacy_effect":"","amount":0.0},
 "HarvestToolModule":{"power":20.0,"quality_power":1.0,"efficiency":1.0,"quality_yield":1.0,"stamina":3.0,"targets":{"rock":1.0},"resources":{"bi.resource.stone":1.0},"critical_multiplier":1.5},
 "WeaponModule":{"weapon_id":"bi.weapon.sword.basic"},
 "SpoilageModule":{"duration":120.0,"result_item_id":"bi.resource.rotten_flesh"},
 "BuildingItemModule":{"definition_id":"foundation"},
 "ProjectileModule":{"speed":20.0},
 "WaterContainerModule":{"capacity":10.0,"watering_cost":1.0,"freshwater_only":true}}
const EFFECT_TYPES := ["Damage","ModifyStat","ApplyStatus","SpawnEntity","PlayEffect","GiveItem","RemoveItem","CheckCondition"]
const TRIGGERS := ["OnUse","OnHit","OnHarvestHit","OnConsume"]
const WEAPON_CLASSES := ["Sword","Dagger","Club","Axe","Hammer","Bow"]
static func prototype(section: String) -> Dictionary:
	match section:
		"items": return {"id":"bi.item.new","title":"","name_key":"item.new.name","description_key":"item.new.description","category":"RESOURCE","icon":"◆","stack_limit":256,"world_visual_id":"","tags":[],"modules":[]}
		"recipes": return {"id":"bi.recipe.new","name":"","name_key":"recipe.new.name","icon":"◆","ingredients":[{"item_id":"bi.resource.wood","quantity":1}],"outputs":[{"item_id":"bi.build.foundation","quantity":1}],"craft_duration":1.0,"station_requirements":[]}
		"weapons": return {"id":"bi.weapon.new","weapon_class":"Sword","base_damage":18.0,"attack_speed":1.0,"move_modifier":1.0,"knockback":2.0,"crit_chance":0.0,"crit_multiplier":1.5,"moveset_id":"sword.training.v1","visual_profile_id":"bi.visual.sword.lpc","effects":[]}
		"visual_profiles": return {"id":"bi.visual.new","mode":"LPC_LAYER","lpc_asset_id":"lpc.weapon.sword"}
		"effects": return {"id":"bi.effect.new","triggers":{"OnConsume":"start"},"nodes":[{"id":"start","type":"ModifyStat","stat":"health","amount":20.0,"next":[]}]}
	return {}
static func array_default(key: String) -> Variant:
	match key:
		"ingredients","outputs": return {"item_id":"bi.resource.wood","quantity":1}
		"modules": return {"type":"ConsumableModule","effects":[]}
		"nodes": return effect_node("ModifyStat")
	if key.ends_with("_curve"): return [0.0,0.0]
	return ""

static func effect_node(type: String) -> Dictionary:
	var params: Dictionary = {"Damage":{"amount":18.0},"ModifyStat":{"stat":"health","amount":20.0},"ApplyStatus":{"status_id":"bi.status.fire.test","duration":2.0},"SpawnEntity":{"entity_id":"bi.entity.qa_spark"},"PlayEffect":{"effect_id":"bi.vfx.hit.test"},"GiveItem":{"item_id":"bi.resource.wood","quantity":1},"RemoveItem":{"item_id":"bi.resource.wood","quantity":1},"CheckCondition":{"condition":"player_health_below","threshold":50.0,"tag":"combat_targets","chance":0.5}}.get(type,{})
	params.merge({"id":"new_node","type":type,"next":[]})
	return params
