class_name NativeTerrainGraph
extends RefCounted
## Main-thread graph authoring only. Native Voxel Tools evaluates every base voxel.
const CHANNELS := (1<<VoxelBuffer.CHANNEL_SDF)|(1<<VoxelBuffer.CHANNEL_INDICES)|(1<<VoxelBuffer.CHANNEL_WEIGHTS)
var generator := VoxelGeneratorGraph.new()
var function: VoxelGraphFunction = generator.get_main_function()
var x: int
var y: int
var z: int
var height: int
var _negative_literal := RegEx.create_from_string("(^|[+*/,(\\-])-(\\d+(?:\\.\\d+)?)")

func _init() -> void:
	x = expression("a*0.5",{"a":node(VoxelGraphFunction.NODE_INPUT_X)})
	y = expression("a*0.5",{"a":node(VoxelGraphFunction.NODE_INPUT_Y)})
	z = expression("a*0.5",{"a":node(VoxelGraphFunction.NODE_INPUT_Z)})
	generator.use_xz_caching = true
	generator.use_subdivision = true
	generator.subdivision_size = 16
	generator.use_optimized_execution_map = true
	generator.sdf_clip_threshold = 1.5

func node(type: int) -> int:
	return function.create_node(type,Vector2(function.get_node_ids().size()*24,0))

func expression(code: String, inputs: Dictionary = {}) -> int:
	# Voxel Tools expression grammar has no unary-minus operator after * or -.
	code = _negative_literal.sub(code,"$1(0-$2)",true)
	# v1.7x treats a variable before an operator + '(' as a function name.
	# Explicit identity operands avoid that parser ambiguity (native folding).
	for key: String in inputs:
		code = RegEx.create_from_string("\\b"+key+"\\b").sub(code,"("+key+"*1)",true)
	var id := node(VoxelGraphFunction.NODE_EXPRESSION)
	function.set_node_param(id,0,code)
	function.set_expression_node_inputs(id,PackedStringArray(inputs.keys()))
	var port := 0
	for key: String in inputs:
		function.add_connection(int(inputs[key]),0,id,port)
		port += 1
	return id

func noise(seed_value: int, frequency: float, nx: int, nz: int, octaves: int = 2) -> int:
	var resource := FastNoiseLite.new()
	resource.seed = seed_value
	resource.frequency = frequency
	resource.fractal_octaves = octaves
	var id := node(VoxelGraphFunction.NODE_NOISE_2D)
	function.set_node_param(id,0,resource)
	function.add_connection(nx,0,id,0)
	function.add_connection(nz,0,id,1)
	return id

func smooth(source: int, low: float, high: float) -> int:
	var id := node(VoxelGraphFunction.NODE_SMOOTHSTEP)
	function.set_node_param(id,0,low)
	function.set_node_param(id,1,high)
	function.add_connection(source,0,id,0)
	return id

func less(source: int, threshold: float) -> int:
	var id := node(VoxelGraphFunction.NODE_SELECT)
	function.set_node_default_input(id,0,1.0)
	function.set_node_default_input(id,1,0.0)
	function.set_node_param(id,0,threshold)
	function.add_connection(source,0,id,2)
	return id

func output(sdf: int, sand: int, rock: int, dirt: int) -> Dictionary:
	var out := node(VoxelGraphFunction.NODE_OUTPUT_SDF)
	function.add_connection(sdf,0,out,0)
	var grass := expression("max(0,1-a-b-c)",{"a":sand,"b":rock,"c":dirt})
	var weights := [sand,grass,dirt,rock]
	for index: int in 4:
		var weight := node(VoxelGraphFunction.NODE_OUTPUT_WEIGHT)
		function.set_node_param(weight,0,index)
		function.add_connection(weights[index],0,weight,0)
	return generator.compile()

func build_v2(profile: Dictionary, seed_value: int, lakes: Array = [], river: Dictionary = {}) -> Dictionary:
	var warp: Dictionary = profile.domain_warp
	var wx := expression("a+b*%.7f"%float(warp.amplitude_m),{"a":x,"b":noise(seed_value+17,float(warp.frequency),x,z,int(warp.octaves))})
	var wz := expression("a+b*%.7f"%float(warp.amplitude_m),{"a":z,"b":noise(seed_value+41,float(warp.frequency),x,z,int(warp.octaves))})
	var radial := expression("sqrt((a/%.7f)*(a/%.7f)+(b/%.7f)*(b/%.7f))"%[profile.dimensions_m[0]*.5,profile.dimensions_m[0]*.5,profile.dimensions_m[1]*.5,profile.dimensions_m[1]*.5],{"a":wx,"b":wz})
	radial = expression("a+b*%.7f"%float(profile.coastline.irregularity),{"a":radial,"b":noise(seed_value+71,.018,x,z)})
	var beach := smooth(radial,float(profile.coastline.beach_start),1)
	var center := expression("1-a",{"a":smooth(radial,sqrt(float(profile.highland_ratio))*.85,float(profile.highland_radius))})
	var macro := expression("clamp(0.5+a*0.9,0,1)",{"a":noise(seed_value+101,float(profile.macro_frequency),wx,wz,2)})
	var terraces := expression("0")
	for level: int in range(1,5):
		var threshold := float(level)*.19
		var band := smooth(macro,threshold-float(profile.plateau_blend),threshold+float(profile.plateau_blend))
		terraces = expression("a+b",{"a":terraces,"b":band})
	var deep := smooth(radial,1,float(profile.coastline.deep_radius))
	height = expression("(%.7f+b*c*%.7f)*(1-a)+d*%.7f"%[float(profile.lowland_height),float(profile.elevation_step),float(profile.deep_ocean_level)*float(profile.elevation_step)],{"a":beach,"b":terraces,"c":center,"d":deep})
	# Calm pockets are designed into the macro field; spawn is a flat clearing.
	var spawn := smooth(expression("sqrt(a*a+b*b)",{"a":x,"b":z}),18,42)
	height = expression("%.7f*(1-b)+a*b"%float(profile.lowland_height),{"a":height,"b":spawn})
	for lake: Dictionary in lakes:
		var r := expression("sqrt(((a-%.7f)/%.7f)*((a-%.7f)/%.7f)+((b-%.7f)/%.7f)*((b-%.7f)/%.7f))+c*%.7f"%[lake.center[0],lake.radii[0],lake.center[0],lake.radii[0],lake.center[1],lake.radii[1],lake.center[1],lake.radii[1],float(profile.lakes.shore_irregularity)],{"a":x,"b":z,"c":noise(seed_value+int(lake.index)+211,.075,x,z)})
		var bank := smooth(r,.20,1.3)
		height = expression("min(a,%.7f*(1-b)+a*b)"%float(lake.level-lake.depth),{"a":height,"b":bank})
	var points: Array = river.get("points",[])
	for index: int in range(maxi(0,points.size()-1)):
		var a: Array = points[index]
		var b: Array = points[index+1]
		var dx := float(b[0])-float(a[0])
		var dz := float(b[2])-float(a[2])
		var length2 := maxf(.01,dx*dx+dz*dz)
		var ratio := expression("clamp(((x-%.7f)*%.7f+(z-%.7f)*%.7f)/%.7f,0,1)"%[a[0],dx,a[2],dz,length2],{"x":x,"z":z})
		var r := expression("sqrt((x-(%.7f+t*%.7f))*(x-(%.7f+t*%.7f))+(z-(%.7f+t*%.7f))*(z-(%.7f+t*%.7f)))/%.7f"%[a[0],dx,a[0],dx,a[2],dz,a[2],dz,float(river.width)],{"x":x,"z":z,"t":ratio})
		var bank := smooth(r,.25,1.9)
		height = expression("min(h,(%.7f*(1-t)+%.7f*t-%.7f)*(1-b)+h*b)"%[a[1],b[1],float(river.depth)],{"h":height,"t":ratio,"b":bank})
	var sdf := expression("(a-b)*2",{"a":y,"b":height})
	var sand := expression("1-a",{"a":smooth(height,2.5,5.0)})
	var rock := smooth(expression("b-a",{"a":y,"b":height}),10,13)
	var dirt := expression("(1-a)*(1-b)*c",{"a":sand,"b":rock,"c":smooth(expression("b-a",{"a":y,"b":height}),6,9)})
	rock = expression("(1-a)*b",{"a":sand,"b":rock})
	return output(sdf,sand,rock,dirt)

func build_legacy(field: IslandField) -> Dictionary:
	# Preserve v1's +/-8 voxel-unit clamp rather than clipping distant values
	# to the graph's uniform +/-500 sentinel. Godot's buffer API scales SDF16.
	generator.sdf_clip_threshold = 16.0
	var n := noise(field.world_seed,.012,x,z,3)
	var clearing := smooth(expression("sqrt(a*a+b*b)",{"a":x,"b":z}),16,42)
	height = expression("12*(1-b)+(14+16*a)*b",{"a":n,"b":clearing})
	var lake_r := expression("sqrt((a+72)*(a+72)+(b-48)*(b-48))",{"a":x,"b":z})
	var lake_edge := smooth(lake_r,18,28)
	height = expression("min(h,4+5*(r/18)*(r/18))*(1-t)+h*t",{"h":height,"r":lake_r,"t":lake_edge})
	var radial := expression("(a/240)*(a/240)+(b/210)*(b/210)",{"a":x,"b":z})
	var body := expression("(sqrt(a+((b+35)/65)*((b+35)/65))-1)*50",{"a":radial,"b":y})
	var top := expression("min(h,-35+65*sqrt(max(0,1-r)))",{"h":height,"r":radial})
	var sdf := expression("clamp(max(a,b-h)*2,-8,8)",{"a":body,"b":y,"h":height})
	var depth := expression("h-y",{"h":top,"y":y})
	var below_soil := less(expression("8-d",{"d":depth}),0)
	var sand := expression("a*(1-b)",{"a":less(y,3.5),"b":below_soil})
	var rock := expression("max(a,b)",{"a":less(expression("12-d",{"d":depth}),0),"b":less(expression("23-y",{"y":y}),0)})
	var dirt := expression("d*(1-r)*(1-s)",{"d":below_soil,"r":rock,"s":sand})
	sand = expression("a*(1-b)",{"a":sand,"b":rock})
	return output(sdf,sand,rock,dirt)
