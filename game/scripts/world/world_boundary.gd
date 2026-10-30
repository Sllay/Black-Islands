class_name WorldBoundary
extends RefCounted
## Smooth outer-ocean treadmill hook and deterministic hard recovery policy.

const SOFT_START := 320.0
const SOFT_END := 440.0
const HARD_LIMIT := 480.0
static var _soft_start := SOFT_START
static var _soft_end := SOFT_END
static var _hard_limit := HARD_LIMIT
static var _floor := -128.0

static func configure_field(field: IslandField) -> void:
	var config: Dictionary = field.profile.boundary if field is WorldFieldV2 else {}
	_soft_start = float(config.get("soft_start_m",SOFT_START))
	_soft_end = float(config.get("soft_end_m",SOFT_END))
	_hard_limit = float(config.get("hard_limit_m",HARD_LIMIT))
	_floor = float(config.get("floor_m",-128))

static func attenuate(point: Vector3, motion: Vector3) -> Vector3:
	var horizontal := Vector3(point.x, 0, point.z)
	var distance := horizontal.length()
	if distance <= _soft_start:
		return motion
	var normal := horizontal.normalized()
	var outward := maxf(0.0, motion.dot(normal))
	return motion - normal * outward * smoothstep(_soft_start, _soft_end, distance)

static func outside(point: Vector3) -> bool:
	return not point.is_finite() or Vector2(point.x, point.z).length() >= _hard_limit or point.y < _floor or point.y > 256.0
