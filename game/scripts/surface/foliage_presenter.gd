class_name FoliagePresenter
extends Node3D
## Patch-local batches, zero per-blade Nodes. Interactive colliders are separate.
var runtime: SurfaceRuntime
var patches: Dictionary = {}
var actors: Dictionary = {}
var generated: Dictionary = {}
var pending: Array[Vector2i] = []
var instances := 0
var grass_instances := 0
var patch_updates := 0
var _poll := 0.0

func _process(delta: float) -> void:
	if runtime == null or not runtime.player.spawned:
		return
	_poll += delta
	if _poll >= .5:
		_poll = 0
		_reconcile()
	if not pending.is_empty():
		_build(pending.pop_front())

func _reconcile() -> void:
	var point := runtime.player.global_position
	var center := Vector2i(floori(point.x/PropField.PATCH),floori(point.z/PropField.PATCH))
	var desired: Dictionary = {}
	for z: int in range(center.y-2,center.y+3):
		for x: int in range(center.x-2,center.x+3):
			var key := Vector2i(x,z)
			desired[key] = true
			if not patches.has(key) and key not in pending:
				pending.append(key)
	for key: Vector2i in patches.keys():
		if not desired.has(key):
			for row: Dictionary in generated[key]:
				runtime.candidates.erase(row.id)
			patches[key].queue_free()
			patches.erase(key)
			generated.erase(key)
	var near: Dictionary = {}
	for key: Vector2i in generated:
		for row: Dictionary in generated[key]:
			if runtime.definition(row.definition).harvest.is_empty() or runtime.destroyed(row.id):
				continue
			var location := Vector3(row.point[0],row.point[1],row.point[2])
			if runtime.ledger.suppressed(location):
				continue
			if runtime.edited_patches.has(key):
				var hit := runtime.terrain.surface_hit(location.x,location.z)
				if hit.is_empty() or absf(float(hit.position.y)-location.y) > .55:
					continue
			if point.distance_to(location) > 9:
				continue
			near[row.id] = true
			if not actors.has(row.id):
				var actor := PropActor.new()
				actor.name = "HarvestProp"
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
		var patch := AABB(Vector3(key.x*16,-128,key.y*16),Vector3(16,384,16))
		if patch.intersects(area) and key not in pending:
			pending.append(key)

func _build(key: Vector2i) -> void:
	if patches.has(key):
		patches[key].queue_free()
	var root := Node3D.new()
	add_child(root)
	patches[key] = root
	var rows := runtime.field.candidates(key)
	generated[key] = rows
	var grouped: Dictionary = {}
	for row: Dictionary in rows:
		runtime.candidates[row.id] = row
		var point := Vector3(row.point[0],row.point[1],row.point[2])
		if runtime.destroyed(row.id) or runtime.ledger.suppressed(point):
			continue
		if row.definition == "grass" and Vector2(point.x-runtime.player.position.x,point.z-runtime.player.position.z).length() > 24:
			continue
		if runtime.edited_patches.has(key):
			var hit := runtime.terrain.surface_hit(point.x,point.z)
			if hit.is_empty() or absf(hit.position.y-point.y) > .55:
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
			batch.set_instance_transform(index,Transform3D(Basis(Vector3.UP,float(row.yaw)).scaled(Vector3.ONE*float(row.scale)),Vector3(row.point[0],row.point[1],row.point[2])))
		var view := MultiMeshInstance3D.new()
		view.name = id
		view.multimesh = batch
		view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(view)
	patch_updates += 1
	_recount()

func _recount() -> void:
	instances = 0
	grass_instances = 0
	for root: Node3D in patches.values():
		for batch: MultiMeshInstance3D in root.get_children():
			instances += batch.multimesh.instance_count
			if batch.name == "grass":
				grass_instances += batch.multimesh.instance_count
