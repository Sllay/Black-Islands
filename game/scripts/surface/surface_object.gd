class_name SurfaceObject
extends StaticBody3D
## Thin presentation adapter for structures, FarmPlots and inventory packages.
var runtime: SurfaceRuntime
var object_id: String
var role: String

func interact(_actor: PlayerActor) -> void:
	runtime.interact_object(object_id,role)
