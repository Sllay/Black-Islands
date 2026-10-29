class_name SurfaceObjects
extends Node3D
## Reconcile presentation from state only on mutations / coarse distance events.
var runtime: SurfaceRuntime
var views: Dictionary = {}
var _meshes: Dictionary = {}
var _materials: Dictionary = {}

func _mesh(size: Vector3) -> BoxMesh:
	if not _meshes.has(size):
		var mesh := BoxMesh.new()
		mesh.size = size
		_meshes[size] = mesh
	return _meshes[size]

func _material(color: Color) -> StandardMaterial3D:
	if not _materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = color
		material.roughness = 1
		_materials[color] = material
	return _materials[color]

func reconcile() -> void:
	var rows: Dictionary = {}
	for id: String in runtime.building.pieces:
		var piece: Dictionary = runtime.building.pieces[id]
		var cell := SupportGraph.cell(piece)
		var dimensions: Array = SurfaceCatalog.data().structures[piece.definition].dimensions
		var size := Vector3(dimensions[0],dimensions[1],dimensions[2])
		var point := Vector3(cell)+Vector3(.5,size.y*.5,.5)
		if piece.definition == "wall":
			point = Vector3(cell)+Vector3(1,1,.5) if int(piece.rotation) == 0 else Vector3(cell)+Vector3(.5,1,1)
			if int(piece.rotation) == 1:
				size = Vector3(size.z,size.y,size.x)
		var colors := {"thatch":"bfa773","wood":"ae8962","stone":"89969f","darkstone":"515575","scrap":"887365","iron":"aac5c4"}
		rows[id] = {"position":point,"size":size,"color":Color(colors[piece.tier]),"role":"structure"}
	for id: String in runtime.farms.plots:
		var plot: Dictionary = runtime.farms.plots[id]
		var point := Vector3(plot.position[0],plot.position[1],plot.position[2])
		rows[id] = {"position":point+Vector3(0,.035,0),"size":Vector3(.94,.07,.94),"color":Color("705442") if plot.moisture <= 0 else Color("4e4036"),"role":"farm","stage":int(plot.growth_stage),"seeded":not plot.seed_id.is_empty()}
	for id: String in runtime.containers.records:
		var row: Dictionary = runtime.containers.records[id]
		rows[id] = {"position":Vector3(row.position[0],row.position[1],row.position[2])+Vector3.UP*.22,"size":Vector3(.75,.44,.5),"color":Color("b49560") if row.kind == "Chest" else Color("bdb087"),"role":"container"}
	for id: String in views.keys():
		if not rows.has(id) or views[id].get_meta("row") != rows[id] or views[id].position.distance_to(runtime.player.position) > 64:
			views[id].queue_free()
			views.erase(id)
	for id: String in rows:
		var row: Dictionary = rows[id]
		if views.has(id) or row.position.distance_to(runtime.player.position) > 64:
			continue
		var view := SurfaceObject.new()
		view.runtime = runtime
		view.object_id = id
		view.role = row.role
		view.position = row.position
		view.collision_layer = 16 if row.role == "structure" else 4
		view.collision_mask = 0
		view.add_to_group("build_surfaces" if row.role == "structure" else "interactables")
		var visual := MeshInstance3D.new()
		visual.mesh = _mesh(row.size)
		visual.material_override = _material(row.color)
		view.add_child(visual)
		var shape := BoxShape3D.new()
		shape.size = row.size
		var collision := CollisionShape3D.new()
		collision.shape = shape
		view.add_child(collision)
		if row.get("seeded",false):
			var plant := MeshInstance3D.new()
			plant.mesh = load("res://resources/surface/plant.res")
			plant.scale = Vector3.ONE*(.4+float(row.stage)*.23)
			plant.position.y = .1
			view.add_child(plant)
		view.set_meta("row",row)
		add_child(view)
		views[id] = view
