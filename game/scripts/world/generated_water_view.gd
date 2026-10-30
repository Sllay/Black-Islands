class_name GeneratedWaterView
extends Node3D
## Sleeping lake/river surfaces derived from metadata, no flow solver or collider.
var field: WorldFieldV2

func _ready() -> void:
	var material: Material = load("res://resources/world/OceanMaterial.tres")
	for lake: Dictionary in field.lakes:
		var points: Array[Vector3] = []
		var center := Vector2(lake.center[0],lake.center[1])
		for index: int in 49:
			var angle := index*TAU/48
			var direction := Vector2(cos(angle)*float(lake.radii[0]),sin(angle)*float(lake.radii[1]))
			var low := .1
			var high := 1.35
			for step: int in 8:
				var radius := (low+high)*.5
				var sample := center+direction*radius
				if field.density(Vector3(sample.x,float(lake.level),sample.y)) > 0:
					low = radius
				else:
					high = radius
			var point := center+direction*low
			points.append(Vector3(point.x,float(lake.level)+.025,point.y))
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for index: int in 48:
			for point: Vector3 in [Vector3(center.x,float(lake.level)+.025,center.y),points[index],points[index+1]]:
				tool.set_normal(Vector3.UP)
				tool.add_vertex(point)
		_add(tool.commit(),material,str(lake.id))
	var river: Array = field.river.get("points",[])
	if river.size() < 2:
		return
	var river_mesh := SurfaceTool.new()
	river_mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index: int in range(river.size()-1):
		var start := Vector3(river[index][0],river[index][1]+.035,river[index][2])
		var end := Vector3(river[index+1][0],river[index+1][1]+.035,river[index+1][2])
		var side := Vector3(end.z-start.z,0,start.x-end.x).normalized()*float(field.river.width)*.9
		for point: Vector3 in [start-side,start+side,end+side,start-side,end+side,end-side]:
			river_mesh.set_normal(Vector3.UP)
			river_mesh.add_vertex(point)
	_add(river_mesh.commit(),material,"River")

func _add(mesh: Mesh, material: Material, label: String) -> void:
	var view := MeshInstance3D.new()
	view.name = label
	view.mesh = mesh
	view.material_override = material
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)
