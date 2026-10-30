class_name WaterTile
extends RefCounted
## Structure-of-arrays, never a scene object. Depths are metres, volumes m³.
enum Activity { INACTIVE, SLEEPING, ACTIVE }
var coord: Vector2i
var side: int
var ground := PackedFloat32Array()
var depth := PackedFloat32Array()
var previous := PackedFloat32Array()
var change := PackedFloat32Array()
var flow_x := PackedFloat32Array()
var flow_z := PackedFloat32Array()
var kind := PackedByteArray() # 0dry,1lake,2ocean reservoir,3river,4salt (finite)
var activity := Activity.SLEEPING
var quiet := 0
var revision := 0
func _init(address: Vector2i, size: int) -> void:
	coord = address
	side = size
	ground.resize(size*size)
	depth.resize(size*size)
	previous.resize(size*size)
	change.resize(size*size)
	flow_x.resize(size*size)
	flow_z.resize(size*size)
	kind.resize(size*size)
func wake() -> void:
	activity = Activity.ACTIVE
	quiet = 0
func bytes_used() -> int:
	return side*side*(6*4+1)
