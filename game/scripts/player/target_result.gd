class_name TargetResult
extends RefCounted
## Reused central result. Consumers copy authoritative fields when committing an action.

enum Kind { NONE, TERRAIN, BUILD_GRID, INTERACTABLE, COMBAT_TARGET }
var kind: Kind = Kind.NONE
var world_position := Vector3.ZERO
var normal := Vector3.UP
var entity: Node3D
var voxel := Vector3i.ZERO
var build_cell := Vector3i.ZERO
var build_edge := ""
var distance := 0.0
var available_actions: Array[StringName] = []

func clear() -> void:
	kind = Kind.NONE
	entity = null
	build_edge = ""
	distance = 0
	available_actions.clear()

func summary() -> Dictionary:
	return {"type": Kind.keys()[kind], "position": world_position, "normal": normal,
		"voxel": voxel, "build_cell": build_cell, "build_edge": build_edge, "distance": distance,"available_actions":available_actions}
