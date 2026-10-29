class_name SurfaceObject
extends Node3D
## Thin presentation adapter for structures, FarmPlots and inventory packages.
var runtime: SurfaceRuntime
var object_id: String
var role: String

func available_actions(actor: PlayerActor) -> Array[String]:
	if role == "structure":
		return ["demolish"] if actor.camera_rig.build_mode else []
	if role == "container":
		return ["open"]
	return ["inspect","interact"] if runtime.farms.plots.has(object_id) else []

func interact(actor: PlayerActor) -> void:
	var item := actor.inventory.state.active_definition()
	if role == "farm" and item != null and item.id == "bi.tool.watering_can":
		runtime.farms.water(object_id)
		runtime.objects.reconcile()
	else:
		runtime.interact_object(object_id,role)
