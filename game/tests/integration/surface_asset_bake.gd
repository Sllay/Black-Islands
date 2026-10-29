extends Node
## Engine-authored placeholder meshes, shared by instancing and gameplay views.
func _ready() -> void:
	var brown := Color("77563a")
	var green := Color("52905a")
	var specs := {
		"tree":[["trunk",brown,Vector3(0,1,0),Vector3(.3,2,.3)],["ball",green,Vector3(0,2.7,0),Vector3(2.4,2.7,2.4)]],
		"forest":[["trunk",brown,Vector3(0,1.4,0),Vector3(.4,2.8,.4)],["cone",Color("325d49"),Vector3(0,2.4,0),Vector3(3,3,3)],["cone",green,Vector3(0,3.5,0),Vector3(2,2,2)]],
		"palm":[["trunk",brown,Vector3(0,1.5,0),Vector3(.25,3,.25)],["ball",green,Vector3(0,3,0),Vector3(4,.6,1.3)],["ball",green,Vector3(0,3,0),Vector3(1.3,.6,4)]],
		"rock":[["ball",Color("808e9e"),Vector3(0,.65,0),Vector3(1.6,1.6,1.5)]],
		"ore":[["ball",Color("696b89"),Vector3(0,.65,0),Vector3(1.7,1.6,1.5)],["cone",Color("9abbb7"),Vector3(.2,1.1,.2),Vector3(.6,.9,.5)]],
		"pebble":[["ball",Color("8e9c94"),Vector3(0,.13,0),Vector3(.45,.35,.4)]],
		"bush":[["ball",Color("387b51"),Vector3(0,.4,0),Vector3(1.2,.9,1.1)]],
		"plant":[["cone",Color("88af70"),Vector3(0,.3,0),Vector3(.55,.6,.55)]],
		"grass":[["cone",Color("b0c877"),Vector3(0,.17,0),Vector3(.12,.34,.12)],["cone",Color("83a961"),Vector3(.1,.14,.05),Vector3(.12,.28,.12)]]}
	DirAccess.make_dir_recursive_absolute("res://resources/surface")
	for id: String in specs:
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: Array in specs[id]:
			var primitive: PrimitiveMesh
			if part[0] == "trunk" or part[0] == "cone":
				var cylinder := CylinderMesh.new()
				cylinder.height = 1
				cylinder.top_radius = 0 if part[0] == "cone" else .5
				cylinder.bottom_radius = .5
				cylinder.radial_segments = 6
				primitive = cylinder
			else:
				var sphere := SphereMesh.new()
				sphere.height = 1
				sphere.radius = .5
				sphere.radial_segments = 8
				sphere.rings = 3
				primitive = sphere
			var arrays := primitive.get_mesh_arrays()
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var basis := Basis.IDENTITY.scaled(part[3])
			for index: int in indices:
				builder.set_color(part[1])
				builder.set_normal((basis.inverse().transposed()*normals[index]).normalized())
				builder.add_vertex(basis*vertices[index]+Vector3(part[2]))
		var mesh := builder.commit()
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 1
		mesh.surface_set_material(0,material)
		assert(ResourceSaver.save(mesh,"res://resources/surface/"+id+".res") == OK)
	print("SURFACE_ASSETS PASS ",specs.size())
	get_tree().quit()
