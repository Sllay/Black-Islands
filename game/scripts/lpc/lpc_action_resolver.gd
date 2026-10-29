class_name LPCActionResolver
extends RefCounted
## Gameplay semantics are independent of upstream clip names/row layout.
const IDLE := "IDLE"
const MOVE := "MOVE"
const RUN := "RUN"
const MELEE_SLASH := "MELEE_SLASH"
const HURT := "HURT"
const DODGE := "DODGE"

static func resolve(action: String, appearance: LPCAppearance) -> Dictionary:
	if appearance.clips.has(action):
		return {"clip":action, "pose":false, "fallback":false}
	if action == RUN or action == DODGE:
		return {"clip":MOVE, "pose":false, "fallback":true}
	return {"clip":MOVE, "pose":true, "fallback":true} # Idle is an explicit walk pose in this slice.

static func direction(world_direction: Vector3, heading: float, previous: int = 2) -> int:
	var local := world_direction.rotated(Vector3.UP, -heading)
	if local.length_squared() < 0.0001:
		return previous
	if absf(local.x) > absf(local.z):
		return 3 if local.x > 0.0 else 1
	return 2 if local.z > 0.0 else 0
