class_name PropActor
extends StaticBody3D
## Near-only collision/interaction adapter. Visible props stay in MultiMeshes.
var spawn_id: String
var definition_id := ""
var runtime: SurfaceRuntime
func _ready() -> void:
	add_to_group("interactables")
	collision_layer = CollisionLayers.PROP
	collision_mask = 0
	var collision := CollisionShape3D.new()
	var shape := CapsuleShape3D.new()
	shape.radius = .45
	shape.height = 1.8
	collision.position.y = .9
	collision.shape = shape
	add_child(collision)
	var query := InteractionVolume.new()
	query.position.y = .9
	query.configure(self,shape)
	add_child(query)
	if not definition_id.is_empty() and runtime.definition(definition_id).get("visual") is Dictionary:
		PropVisual.attach(self,runtime.definition(definition_id))
		name = "MineralRootActor" if runtime.definition(definition_id).kind == "MineralRoot" else "BoulderActor"

func available_actions(actor: PlayerActor) -> Array[String]:
	var item := actor.inventory.state.active_definition()
	return ["harvest"] if item != null and not item.module("HarvestToolModule").is_empty() else []

func interact(player: PlayerActor) -> void:
	runtime.harvest_prop(spawn_id,player)
