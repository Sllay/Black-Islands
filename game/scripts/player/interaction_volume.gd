class_name InteractionVolume
extends Area3D
## Query shape points to the authoritative adapter; it never blocks a body.
var subject: Node3D

func configure(owner_node: Node3D, shape: Shape3D) -> void:
	subject = owner_node
	collision_layer = CollisionLayers.QUERY
	collision_mask = 0
	monitoring = false
	var collision := CollisionShape3D.new()
	collision.shape = shape
	add_child(collision)
