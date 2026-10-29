class_name AttackDefinition
extends Resource
## Timings/geometry belong to content, not the player or LPC animation frames.
@export var id: String
@export var semantic_action := LPCActionResolver.MELEE_SLASH
@export var windup := 0.1
@export var active_duration := 0.14
@export var recovery := 0.24
@export var damage := 18.0
@export var stamina_cost := 8.0
@export var shape: Shape3D
@export var offset := Vector3(0,0.8,-1.1)
@export var knockback := 2.0
@export var hitstop := 0.035
@export var multihit := false
@export var multihit_interval := 0.15

func duration() -> float:
	return windup + active_duration + recovery
