class_name DodgeDefinition
extends Resource
@export var stamina_cost := 24.0
@export var burst_speed := 11.0
@export var burst_seconds := 0.25
@export var duration := 0.55
@export var iframe_start := 0.045
@export var iframe_end := 0.22

func invulnerable(elapsed: float) -> bool:
	return elapsed >= iframe_start and elapsed < iframe_end
