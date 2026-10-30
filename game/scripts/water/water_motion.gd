class_name WaterMotion
extends RefCounted
## Shared actor seam: feet-origin float target, bounded current, no teleport.
var swimming := false
func apply(body: CharacterBody3D, sample: Dictionary, dt: float, tuning: Dictionary) -> void:
	swimming = sample.depth >= tuning.swim_depth and body.global_position.y < sample.level+.1
	if not swimming:
		return
	var error: float = sample.level-tuning.float_offset-body.global_position.y
	body.velocity.y = clampf(body.velocity.y+(error*tuning.buoyancy-body.velocity.y*tuning.drag)*dt,-2.5,2.5)
	var current: Vector3 = sample.current.limit_length(tuning.max_current)
	body.velocity.x = lerpf(body.velocity.x,current.x,clampf(dt*.8,0,1))
	body.velocity.z = lerpf(body.velocity.z,current.z,clampf(dt*.8,0,1))
