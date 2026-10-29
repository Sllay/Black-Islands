class_name StructureModule
extends RefCounted
## Structural footprint is2m; underlying WorldCoordinates/BuildCells remain1m.
const SIZE := 2
const HEIGHT := 2
const SUPPORT_REQUIRED := 5

static func snap(point: Vector3i) -> Vector3i:
	return Vector3i(floori(point.x/2.0)*SIZE,point.y,floori(point.z/2.0)*SIZE)

static func footprint_supported(cell: Vector3i, sample: Callable) -> bool:
	var count := 0
	for z: float in [.15,1.0,1.85]:
		for x: float in [.15,1.0,1.85]:
			count += int(sample.call(Vector3(cell)+Vector3(x,0,z)))
	return count >= SUPPORT_REQUIRED

static func center(cell: Vector3i) -> Vector3:
	return Vector3(cell)+Vector3(1,0,1)
