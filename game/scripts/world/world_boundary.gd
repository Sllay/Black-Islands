class_name WorldBoundary
extends RefCounted
## Smooth outer-ocean treadmill hook and deterministic hard recovery policy.

const SOFT_START := 320.0
const SOFT_END := 440.0
const HARD_LIMIT := 480.0

static func attenuate(point: Vector3, motion: Vector3) -> Vector3:
	var horizontal := Vector3(point.x, 0, point.z)
	var distance := horizontal.length()
	if distance <= SOFT_START:
		return motion
	var normal := horizontal.normalized()
	var outward := maxf(0.0, motion.dot(normal))
	return motion - normal * outward * smoothstep(SOFT_START, SOFT_END, distance)

static func outside(point: Vector3) -> bool:
	return not point.is_finite() or Vector2(point.x, point.z).length() >= HARD_LIMIT or point.y < -128.0 or point.y > 256.0
