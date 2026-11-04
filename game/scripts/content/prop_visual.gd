class_name PropVisual
extends RefCounted
## Shared low-poly placeholder geometry; variants are only data/materials.
static var _base: SphereMesh
static var _ore: PrismMesh
static var _materials: Dictionary = {}
static func parts(definition: Dictionary) -> Array[Dictionary]:
	if _base == null:
		_base = SphereMesh.new()
		_base.radius = 1.0
		_base.height = 1.4
		_base.radial_segments = 8
		_base.rings = 3
		_ore = PrismMesh.new()
		_ore.size = Vector3(1.2,.8,.9)
	var visual: Dictionary = definition.visual
	var result: Array[Dictionary] = [{"name":"BoulderMesh","mesh":_base,"color":visual.get("color","a9aaa0"),"offset":Vector3(0,.6,0)}]
	if visual.get("kind") == "MINERAL_ROOT":
		result.append({"name":"OreOverlayMesh","mesh":_ore,"color":visual.get("ore_color","7b9eaa"),"offset":Vector3(.2,1.0,.1)})
	return result
static func material(color: String) -> StandardMaterial3D:
	if not _materials.has(color):
		var result := StandardMaterial3D.new()
		result.albedo_color = Color(color)
		result.roughness = .85
		_materials[color] = result
	return _materials[color]
static func attach(parent: Node3D, definition: Dictionary) -> void:
	for part: Dictionary in parts(definition):
		var mesh := MeshInstance3D.new()
		mesh.name = part.name
		mesh.mesh = part.mesh
		mesh.material_override = material(part.color)
		mesh.position = part.offset
		parent.add_child(mesh)
