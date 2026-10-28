extends Node

func _ready() -> void:
	_verify.call_deferred()

func _wait_surface(adapter: VoxelTerrainAdapter, point: Vector3) -> bool:
	var deadline := Time.get_ticks_msec() + 45000
	while Time.get_ticks_msec() < deadline:
		await get_tree().physics_frame
		if adapter.is_editable(point, 3) and not adapter.surface_hit(point.x, point.z).is_empty():
			return true
	return false

func _verify() -> void:
	var probe: Node3D = load("res://scenes/debug/WorldTerrainProbe.tscn").instantiate()
	add_child(probe)
	var adapter: VoxelTerrainAdapter = probe.get_node("WorldTerrain")
	if not await _wait_surface(adapter, Vector3(0, 12, 0)):
		_fail("initial native data/collision timeout")
		return
	var before: Vector3 = adapter.surface_hit(0, 0).position
	if absf(before.y - 12.0) > 0.05 or adapter.is_editable(Vector3(1000, 0, 1000), 2):
		_fail("scale or editability guard")
		return
	var started := Time.get_ticks_msec()
	if not adapter.dig_sphere(before, 2):
		_fail("native local edit rejected")
		return
	while Time.get_ticks_msec() - started < 5000:
		await get_tree().physics_frame
		var hit := adapter.surface_hit(0, 0)
		if not hit.is_empty() and hit.position.y < before.y - 1.5:
			break
	var after := adapter.surface_hit(0, 0)
	if after.is_empty() or after.position.y >= before.y - 1.5:
		print("COLLISION_TRACE before=", before, " after=", after, " statistics=", adapter.statistics())
		print("DENSITY_TRACE center=", adapter.density_at(before), " below=", adapter.density_at(before - Vector3(0, 1, 0)))
		_fail("native collision did not rebuild")
		return
	print("NATIVE_EDIT_COLLISION PASS latency_ms=", Time.get_ticks_msec() - started, " before=", before, " after=", after.position)
	probe.get_node("Viewer").position = Vector3(64, 16, 0)
	if not await _wait_surface(adapter, Vector3(64, 12, 0)):
		_fail("WorldChunk-border residency timeout")
		return
	var left := adapter.surface_hit(63.5, 0)
	var right := adapter.surface_hit(64.5, 0)
	if left.is_empty() or right.is_empty():
		_fail("missing collision across WorldChunk border")
		return
	var center := Vector3(64, (left.position.y + right.position.y) * 0.5, 0)
	if not adapter.dig_sphere(center, 2):
		_fail("border edit rejected")
		return
	started = Time.get_ticks_msec()
	var both_updated := false
	while Time.get_ticks_msec() - started < 5000:
		await get_tree().physics_frame
		var a := adapter.surface_hit(63.5, 0)
		var b := adapter.surface_hit(64.5, 0)
		both_updated = not a.is_empty() and not b.is_empty() and a.position.y < left.position.y - 1.0 and b.position.y < right.position.y - 1.0
		if both_updated:
			break
	if not both_updated:
		_fail("border edit did not rebuild both sides")
		return
	print("NATIVE_BORDER_COLLISION PASS x=64m ", adapter.statistics())
	get_tree().quit()

func _fail(message: String) -> void:
	push_error(message)
	get_tree().quit(1)
