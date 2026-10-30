class_name TerrainResidencyAnchor
extends Node
## One native viewer with bounded positional hysteresis, not a second mesh system.
var viewer: VoxelViewer
var subject: Node3D
var hysteresis_metres := 4.0
var moves := 0

func configure(source: Node3D, native_viewer: VoxelViewer) -> void:
	subject = source
	viewer = native_viewer
	viewer.top_level = true
	viewer.global_position = source.global_position

func _process(_delta: float) -> void:
	if is_instance_valid(subject) and subject.global_position.distance_squared_to(viewer.global_position) > hysteresis_metres*hysteresis_metres:
		viewer.global_position = subject.global_position
		moves += 1
