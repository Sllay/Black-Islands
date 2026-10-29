class_name AttackInstance
extends RefCounted
## Reused per controller; IDs here are transient hit-registration keys, not saves.
var sequence := 0
var definition: AttackDefinition
var _hit_at: Dictionary = {}

func begin(attack: AttackDefinition) -> void:
	sequence += 1
	definition = attack
	_hit_at.clear()

func accept(target: Object, elapsed: float) -> bool:
	var id := target.get_instance_id()
	if _hit_at.has(id) and (not definition.multihit or elapsed - float(_hit_at[id]) < definition.multihit_interval):
		return false
	_hit_at[id] = elapsed
	return true
