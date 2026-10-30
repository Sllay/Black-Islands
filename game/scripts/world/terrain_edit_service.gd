class_name TerrainEditService
extends RefCounted
## Intent -> residency validation -> bounded native operation -> durable sparse
## delta -> committed notification. UI never owns terrain/save truth.

signal terrain_changed(area: AABB)
signal operation_completed(operation: Dictionary)
signal operation_failed(operation: Dictionary)
signal intent_queued(operation: Dictionary)
var terrain: VoxelTerrainAdapter
var store: WorldDeltaStore
var last_result: Dictionary = {}
var _before := VoxelBuffer.new()
var _after := VoxelBuffer.new()
var _queue: Dictionary = {}
var _sequence := 0
var accepted := 0
var coalesced := 0
var expired := 0

func apply(center: Vector3, radius: float, paint: bool = false, material: int = 2) -> Error:
	var policy := _policy(center,radius,material)
	if policy != OK:
		return policy
	if not terrain.is_editable(center,radius):
		return ERR_BUSY
	var low := WorldCoordinates.world_to_voxel(center-Vector3.ONE*radius)-Vector3i.ONE*2
	var high := WorldCoordinates.world_to_voxel(center+Vector3.ONE*radius)+Vector3i.ONE*3
	var extent := high-low
	if store is BufferedWorldDeltaStore and not store.has_capacity(extent.x*extent.y*extent.z):
		return ERR_BUSY
	var started := Time.get_ticks_msec()
	terrain.capture_buffer(low,extent,_before)
	var changed := terrain.paint_sphere(center,radius,material) if paint else terrain.dig_sphere(center,radius)
	if not changed:
		return ERR_BUSY
	terrain.capture_buffer(low,extent,_after)
	var changes := terrain.difference(_before,_after,low)
	var error: Error = store.stage(changes) if store is BufferedWorldDeltaStore else store.commit(changes)
	if error != OK:
		terrain.native.get_voxel_tool().paste(low,_before,NativeTerrainGraph.CHANNELS)
		last_result = {"error":error,"rolled_back":true}
		return error
	var area := AABB(WorldCoordinates.voxel_to_world(low),Vector3(extent)*WorldCoordinates.VOXEL_SIZE)
	last_result = {"error":OK,"changed_voxels":changes.size(),"commit_ms":Time.get_ticks_msec()-started,
		"started_ms":started,"paint":paint,"material":material,"area":area,"center":center,"synchronous_disk_write":not store is BufferedWorldDeltaStore}
	terrain_changed.emit(area)
	return OK

func _policy(center: Vector3, radius: float, material: int) -> Error:
	if terrain == null or store == null or not center.is_finite() or not is_finite(radius) or radius <= 0 or radius > 4 or material < 0 or material > 3:
		return ERR_INVALID_PARAMETER
	if terrain.field is WorldFieldV2:
		var profile: Dictionary = terrain.field.profile
		var water: Dictionary = terrain.field.water_at(Vector2(center.x,center.z))
		var floor_height := float(profile.lowland_height)-3*float(profile.elevation_step)
		if water.kind == "ocean" and terrain.field.top_surface(center.x,center.z) < floor_height:
			return ERR_UNAUTHORIZED
		if water.kind == "ocean" and center.y-radius < floor_height:
			return ERR_UNAUTHORIZED
	return OK

func request(center: Vector3, radius: float, paint: bool = false, material: int = 2, actor: Node3D = null, callback: Callable = Callable()) -> Error:
	var policy := _policy(center,radius,material)
	if policy != OK:
		return policy
	var key := "%s:%0.2f:%s:%d"%[center.snapped(Vector3.ONE*.25),radius,paint,material]
	if _queue.has(key):
		_queue[key].deadline = Time.get_ticks_msec()+800
		coalesced += 1
		return OK
	var error := apply(center,radius,paint,material)
	if error == OK:
		accepted += 1
		_finish(last_result.duplicate(),callback)
		return OK
	if error != ERR_BUSY or _queue.size() >= 16:
		return error
	_sequence += 1
	var tool := ""
	if actor is PlayerActor:
		var definition: ItemDefinition = actor.inventory.state.active_definition()
		tool = definition.id if definition != null else ""
	_queue[key] = {"id":_sequence,"center":center,"radius":radius,"paint":paint,"material":material,
		"actor":actor,"needs_actor":actor != null,"tool":tool,"deadline":Time.get_ticks_msec()+800,"callback":callback}
	last_result = {"queued":true,"id":_sequence,"center":center,"error":OK}
	intent_queued.emit(last_result)
	return OK

func poll() -> void:
	for key: String in _queue.keys():
		var intent: Dictionary = _queue[key]
		var error: Error = OK
		if intent.needs_actor and (not is_instance_valid(intent.actor) or intent.actor.global_position.distance_to(intent.center) > 5):
			error = ERR_UNAUTHORIZED
		elif intent.needs_actor and intent.actor is PlayerActor:
			var item: ItemDefinition = intent.actor.inventory.state.active_definition()
			if item == null or item.id != intent.tool:
				error = ERR_UNAVAILABLE
		if error == OK and Time.get_ticks_msec() > int(intent.deadline):
			error = ERR_TIMEOUT
		if error == OK:
			error = apply(intent.center,intent.radius,intent.paint,intent.material)
		if error == ERR_BUSY:
			continue
		_queue.erase(key)
		if error == OK:
			accepted += 1
			var operation := last_result.duplicate()
			operation.id = intent.id
			_finish(operation,intent.callback)
		else:
			expired += 1
			var operation := {"id":intent.id,"error":error,"center":intent.center}
			operation_failed.emit(operation)
			if intent.callback.is_valid():
				intent.callback.call(operation)
		return # At most one native edit per frame, independently of distant jobs.

func _finish(operation: Dictionary, callback: Callable) -> void:
	operation_completed.emit(operation)
	if callback.is_valid():
		callback.call(operation)

func pending_count() -> int:
	return _queue.size()

func cancel_pending(reason: Error = ERR_SKIP) -> void:
	for intent: Dictionary in _queue.values():
		var operation := {"id":intent.id,"center":intent.center,"error":reason}
		operation_failed.emit(operation)
		if intent.callback.is_valid():
			intent.callback.call(operation)
		expired += _queue.size()
	_queue.clear()

func queue_report() -> Dictionary:
	return {"pending":_queue.size(),"accepted":accepted,"coalesced":coalesced,"expired":expired}
