class_name MovesetDefinition
extends Resource
@export var id: String
@export var attacks: Array[AttackDefinition] = []
@export var light_entry: String
@export var heavy_entry: String
@export var transitions: Dictionary = {}
@export var hold_threshold := 0.28
@export var buffer_window := 0.18
@export var combo_timeout := 0.9

func resolve(previous: String, input: String) -> AttackDefinition:
	var entry := light_entry if input == "LIGHT" else heavy_entry
	var target: String = transitions.get(previous + "/" + input, entry)
	for attack: AttackDefinition in attacks:
		if attack.id == target:
			return attack
	return null
