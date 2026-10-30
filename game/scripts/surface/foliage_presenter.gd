class_name FoliagePresenter
extends Node3D
## Stable prop domain + bounded64m presentation. Decorative grass is native.
const REGION := 64.0
var runtime: SurfaceRuntime
var patches: Dictionary = {}
var actors: Dictionary = {}
var generated: Dictionary = {}
var pending: Array[Vector2i] = []
var instances := 0
var grass_instances := 0
var patch_updates := 0
var native_foliage: NativeFoliage
var prop_distance := 72.0
var presentation_enabled := true
var _poll := 0.0
var _task := -1
var _prepared: Array[Dictionary] = []
var _building := Vector2i.ZERO
var _center := Vector2i(999999,999999)
var _desired: Dictionary = {}

func _ready() -> void:
	native_foliage = NativeFoliage.new()
	native_foliage.runtime = runtime
	add_child(native_foliage)
	apply_profile(GameSettings.effective())

func apply_profile(profile: Dictionary) -> void:
	presentation_enabled = true
	native_foliage.apply_budget(profile.foliage)
	prop_distance = float(profile.prop_distance)
	for root: Node3D in patches.values():
		root.visible = true
		for view: MultiMeshInstance3D in root.get_children():
			view.visibility_range_end = prop_distance+24

func apply_quality(quality: String, enabled: bool = true) -> void:
	presentation_enabled = enabled
	var profile: Dictionary = GameSettings.catalog.presets[quality]
	native_foliage.apply_budget(profile.foliage,enabled)
	prop_distance = float(profile.prop_distance)
	for root: Node3D in patches.values():
		root.visible = enabled
		for view: MultiMeshInstance3D in root.get_children():
			view.visibility_range_end = prop_distance+24

func _process(delta: float) -> void:
	if runtime == null or not runtime.player.spawned:
		return
	_poll += delta
	if _poll >= .4:
		_poll = 0
		_reconcile()
	if _task >= 0 and WorkerThreadPool.is_task_completed(_task):
		WorkerThreadPool.wait_for_task_completion(_task)
		_task = -1
		if _desired.has(_building):
			_build(_building,_prepared)
		_prepared = []
	if _task < 0 and not pending.is_empty():
		_building = pending.pop_front()
		_task = WorkerThreadPool.add_task(_prepare.bind(_building,runtime.field),false,"Black Island stable prop candidates")

func _prepare(key: Vector2i, field: PropField) -> void:
	var rows: Array[Dictionary] = []
	for z: int in range(key.y*4,key.y*4+4):
		for x: int in range(key.x*4,key.x*4+4):
			rows.append_array(field.candidates(Vector2i(x,z),false))
	_prepared = rows

func _reconcile() -> void:
	var point := runtime.player.global_position
	var wanted := Vector2i(floori(point.x/REGION),floori(point.z/REGION))
	var envelope := Rect2(Vector2(_center)*REGION-Vector2.ONE*8,Vector2.ONE*(REGION+16))
	if _desired.is_empty() or not envelope.has_point(Vector2(point.x,point.z)):
		_center = wanted
		_desired.clear()
		for z: int in range(_center.y-1,_center.y+2):
			for x: int in range(_center.x-1,_center.x+2):
				var key := Vector2i(x,z)
				_desired[key] = true
				if not patches.has(key) and key not in pending and not (_task >= 0 and _building == key):
					pending.append(key)
		for key: Vector2i in patches.keys():
			if not _desired.has(key):
				for row: Dictionary in generated[key]:
					runtime.candidates.erase(row.id)
				patches[key].queue_free()
				patches.erase(key)
				generated.erase(key)
		for key: Vector2i in pending.duplicate():
			if not _desired.has(key):
				pending.erase(key)
	var near: Dictionary = {}
	for rows: Array in generated.values():
		for row: Dictionary in rows:
			var location := Vector3(row.point[0],row.point[1],row.point[2])
			if point.distance_squared_to(location) > 81 or not row.get("supported",true) or runtime.destroyed(row.id) or runtime.ledger.suppressed(location,false):
				continue
			near[row.id] = true
			if not actors.has(row.id):
				var actor := PropActor.new()
				actor.runtime = runtime
				actor.spawn_id = row.id
				actor.position = location
				add_child(actor)
				actors[row.id] = actor
	for id: String in actors.keys():
		if not near.has(id):
			actors[id].queue_free()
			actors.erase(id)

func invalidate(area: AABB) -> void:
	for key: Vector2i in patches:
		if AABB(Vector3(key.x*REGION,-256,key.y*REGION),Vector3(REGION,512,REGION)).intersects(area) and key not in pending:
			pending.append(key)
	if native_foliage != null:
		native_foliage.mask_dirty = true

func _build(key: Vector2i, rows: Array[Dictionary]) -> void:
	if patches.has(key):
		patches[key].queue_free()
	var root := Node3D.new()
	root.visible = presentation_enabled
	root.position = Vector3(key.x*REGION,0,key.y*REGION)
	add_child(root)
	patches[key] = root
	generated[key] = rows
	var grouped: Dictionary = {}
	for row: Dictionary in rows:
		runtime.candidates[row.id] = row
		var point := Vector3(row.point[0],row.point[1],row.point[2])
		if runtime.destroyed(row.id) or runtime.ledger.suppressed(point,false):
			continue
		var patch := Vector2i(floori(point.x/16),floori(point.z/16))
		if runtime.edited_patches.has(patch):
			# Only local edited cells need exact authoritative SDF support queries.
			row.supported = runtime._density(point-Vector3.UP*.4) < 0 and runtime._density(point+Vector3.UP*.4) > 0
			if not row.supported:
				continue
		if not grouped.has(row.definition):
			grouped[row.definition] = []
		grouped[row.definition].append(row)
	for id: String in grouped:
		var batch := MultiMesh.new()
		batch.transform_format = MultiMesh.TRANSFORM_3D
		batch.mesh = load("res://resources/surface/"+str(runtime.definition(id).visual)+".res")
		batch.instance_count = grouped[id].size()
		for index: int in batch.instance_count:
			var row: Dictionary = grouped[id][index]
			batch.set_instance_transform(index,Transform3D(Basis(Vector3.UP,float(row.yaw)).scaled(Vector3.ONE*float(row.scale)),Vector3(row.point[0],row.point[1],row.point[2])-root.position))
		var view := MultiMeshInstance3D.new()
		view.name = id
		view.multimesh = batch
		view.visibility_range_end = prop_distance+24
		view.visibility_range_end_margin = 12
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(view)
	patch_updates += 1
	_recount()

func _recount() -> void:
	instances = 0
	for root: Node3D in patches.values():
		for batch: MultiMeshInstance3D in root.get_children():
			instances += batch.multimesh.instance_count
	if native_foliage != null:
		grass_instances = int(native_foliage.instancer.debug_get_instance_counts().get(1,0))

func report() -> Dictionary:
	_recount()
	var batches := 0
	for patch: Node3D in patches.values():
		batches += patch.get_child_count()
	var result := native_foliage.report() if native_foliage != null else {}
	result.merge({"resource_instances":instances,"resource_batches":batches,"regions":patches.size(),"active_adapters":actors.size()})
	return result

func cut(point: Vector3, radius: float) -> void:
	for z: int in range(floori(point.z-radius),ceili(point.z+radius)+1):
		for x: int in range(floori(point.x-radius),ceili(point.x+radius)+1):
			var location := Vector3(x+.5,point.y,z+.5)
			if Vector2(location.x-point.x,location.z-point.z).length() > radius:
				continue
			if runtime.ledger.suppressed(location,false):
				continue # Cutting cannot replace construction/path/farm authority.
			runtime.ledger.suppress(location,"cut")
			runtime.ledger.suppression[SurfaceLedger.cell_key(location)].foliage_only = true
			runtime.ledger.release(location,"cut")
	native_foliage.remove_local(point,radius)

func _exit_tree() -> void:
	if _task >= 0:
		WorkerThreadPool.wait_for_task_completion(_task)
