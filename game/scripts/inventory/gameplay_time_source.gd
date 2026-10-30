class_name GameplayTimeSource
extends RefCounted
## Active simulation seconds only. No wall clock/offline progress.
var now := 0.0
var active := true
func advance(delta: float) -> void:
	if active and is_finite(delta) and delta > 0:
		now += delta
