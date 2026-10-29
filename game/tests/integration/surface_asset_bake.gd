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
		"grass":[["cone",Color("b0c877"),Vector3(0,.17,0),Vector3(.12,.34,.12)],["cone",Color("83a961"),Vector3(.1,.14,.05),Vector3(.12,.28,.12)]],
		"mob_chicken":[["ball",Color("f1e8bf"),Vector3(0,.4,0),Vector3(.7,.7,.8)],["ball",Color("f1e8bf"),Vector3(0,.65,-.3),Vector3(.3,.3,.3)],["cone",Color("e4aa56"),Vector3(0,.57,-.49),Vector3(.2,.18,.2)]],
		"mob_boar":[["ball",Color("866b57"),Vector3(0,.6,0),Vector3(1.1,1.1,1.5)],["ball",Color("b09c7c"),Vector3(0,.45,-.7),Vector3(.6,.45,.4)],["cone",Color("eee5cb"),Vector3(.3,.55,-.75),Vector3(.13,.4,.13)]],
		"mob_zombie":[["trunk",Color("71917a"),Vector3(0,.65,0),Vector3(.6,1.3,.4)],["ball",Color("a9b78c"),Vector3(0,1.5,0),Vector3(.55,.55,.5)],["trunk",Color("71917a"),Vector3(.45,.8,0),Vector3(.2,.8,.2)]]}
	DirAccess.make_dir_recursive_absolute("res://resources/surface")
	for id: String in specs:
		var path := "res://resources/surface/"+id+".res"
		var simplify: bool = "--rebake-foliage" in OS.get_cmdline_user_args() and id in ["grass","plant"]
		if FileAccess.file_exists(path) and not simplify:
			continue # Existing authored resource UIDs are preserved.
		var existing := load(path) as ArrayMesh if FileAccess.file_exists(path) else null
		var previous_vertices := existing.surface_get_array_len(0) if existing != null else 0
		var builder := SurfaceTool.new()
		builder.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: Array in specs[id]:
			var primitive: PrimitiveMesh
			if part[0] == "trunk" or part[0] == "cone":
				var cylinder := CylinderMesh.new()
				cylinder.height = 1
				cylinder.top_radius = 0.0 if part[0] == "cone" else .5
				cylinder.bottom_radius = .5
				cylinder.radial_segments = 6
				if simplify:
					cylinder.radial_segments = 3
					cylinder.rings = 1
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
		if existing != null:
			existing.clear_surfaces()
		var mesh := builder.commit(existing)
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = 1
		mesh.surface_set_material(0,material)
		assert(ResourceSaver.save(mesh,path) == OK)
		print("SURFACE_MESH ",id," vertices ",previous_vertices," -> ",mesh.surface_get_array_len(0))
	print("SURFACE_ASSETS PASS ",specs.size())
	get_tree().quit()
