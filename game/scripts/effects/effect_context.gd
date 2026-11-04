class_name EffectContext
extends RefCounted
## Detached data + trusted system-provided hooks. Never read callables from content.
var inventory: InventoryState
var stats := {"health":100.0,"stamina":100.0,"mana":100.0}
var maxima := {"health":100.0,"stamina":100.0,"mana":100.0}
var tags: Array = []
var rng := RandomNumberGenerator.new()
var damage := 0.0
var damage_input := 0.0
var events: Array[Dictionary] = []
