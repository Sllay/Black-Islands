class_name ContainerVisual
extends Node3D
## Event-driven presentation only. No inventory state, input or idle processing.
static var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/world_core/container_visuals.json"))
static var meshes: Dictionary = {}
static var materials: Dictionary = {}
var registry: ContainerService
var identity: String
var lid: Node3D
var tuning: Dictionary
var animation: Tween
var state := "CLOSED"
static func profile(kind: String) -> Dictionary:
	return profiles.get(kind,profiles.WorldDropBag)
func configure(service: ContainerService, id: String) -> void:
	registry = service
	identity = id
	tuning = profile(registry.records[id].kind)
	var dimensions: Array = tuning.size
	var size := Vector3(dimensions[0],dimensions[1],dimensions[2])
	if tuning.shape == "chest":
		_part(self,"BodyVisual","box",size*Vector3(1,.8,1),Vector3.ZERO,tuning.color)
		lid = Node3D.new()
		lid.name = "LidVisual"
		lid.position = Vector3(0,size.y*.4,size.z*.5)
		add_child(lid)
		_part(lid,"LidMesh","box",size*Vector3(1,.18,1),Vector3(0,0,-size.z*.5),tuning.trim)
		registry.open_state_changed.connect(_open_changed)
		_open_changed(id,registry.is_open(id),true)
	else:
		_part(self,"PackageVisual",tuning.shape,size,Vector3.ZERO,tuning.color)
		_part(self,"TieVisual","box",Vector3(size.x*.15,.025,size.z*1.02),Vector3.UP*size.y*.44,tuning.trim)
		if tuning.get("icon",false):
			var icon := Label3D.new()
			icon.name = "ItemIcon"
			for stack: Dictionary in registry.inventories[id].snapshot().slots:
				if not stack.is_empty():
					icon.text = ItemCatalog.resolve(stack.item_id).icon
					break
			icon.pixel_size = .006
			icon.position.y = size.y
			icon.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
			add_child(icon)
func _part(parent: Node3D, title: String, shape: String, size: Vector3, point: Vector3, color: String) -> void:
	var key := shape+str(size)
	if not meshes.has(key):
		var mesh: PrimitiveMesh
		if shape == "sack":
			var sphere := SphereMesh.new()
			sphere.radius = size.x*.5
			sphere.height = size.y
			sphere.radial_segments = 8
			sphere.rings = 4
			mesh = sphere
		else:
			var box := BoxMesh.new()
			box.size = size
			mesh = box
		meshes[key] = mesh
	if not materials.has(color):
		var material := StandardMaterial3D.new()
		material.albedo_color = Color(color)
		material.roughness = .95
		materials[color] = material
	var view := MeshInstance3D.new()
	view.name = title
	view.mesh = meshes[key]
	view.material_override = materials[color]
	view.position = point
	parent.add_child(view)
func _open_changed(id: String, open: bool, immediate: bool = false) -> void:
	if id != identity or lid == null: return
	state = "OPEN" if open else "CLOSED"
	if animation != null: animation.kill()
	var angle := deg_to_rad(float(tuning.lid_degrees)) if open else 0.0
	if immediate or not is_inside_tree(): lid.rotation.x = angle
	else:
		animation = create_tween()
		animation.tween_property(lid,"rotation:x",angle,float(tuning.transition_seconds))
