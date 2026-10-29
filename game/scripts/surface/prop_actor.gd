class_name PropActor
extends StaticBody3D
## Near-only collision/interaction adapter. Visible props stay in MultiMeshes.
var spawn_id: String
var runtime: SurfaceRuntime
func _ready() -> void:
	add_to_group("interactables")
	collision_layer = 4
	collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = .45
	shape.height = 1.8
	collision.position.y = .9
	collision.shape = shape
	add_child(collision)

func interact(player: PlayerActor) -> void:
	runtime.harvest_prop(spawn_id,player)
