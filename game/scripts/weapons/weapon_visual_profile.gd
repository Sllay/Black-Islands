class_name WeaponVisualProfile
extends RefCounted
var id: String
var mode: String
var data: Dictionary
func _init(record: Dictionary) -> void:
	data = record.duplicate(true)
	id = record.id
	mode = record.mode
func sample(curve: String, progress: float, fallback: float) -> float:
	var points: Array = data.get(curve,[])
	if points.is_empty(): return fallback
	var last: Array = points[0]
	for point: Array in points:
		if progress <= float(point[0]):
			var weight := inverse_lerp(float(last[0]),float(point[0]),progress) if float(point[0]) > float(last[0]) else 0.0
			return lerpf(float(last[1]),float(point[1]),clampf(weight,0,1))
		last = point
	return float(last[1])
