class_name WeaponDefinition
extends RefCounted
var id: String
var weapon_class: String
var base_damage: float
var attack_speed: float
var move_modifier: float
var knockback: float
var crit_chance: float
var crit_multiplier: float
var moveset_id: String
var visual_profile_id: String
var effects: Array
func _init(data: Dictionary) -> void:
	id = data.id
	weapon_class = data.weapon_class
	base_damage = float(data.base_damage)
	attack_speed = float(data.attack_speed)
	move_modifier = float(data.move_modifier)
	knockback = float(data.knockback)
	crit_chance = float(data.crit_chance)
	crit_multiplier = float(data.crit_multiplier)
	moveset_id = data.moveset_id
	visual_profile_id = data.visual_profile_id
	effects = data.get("effects",[]).duplicate()
