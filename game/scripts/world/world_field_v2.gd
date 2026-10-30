class_name WorldFieldV2
extends IslandField
## Graph is base truth. Native 2D bake serves immutable metadata queries, not voxels.
var profile: Dictionary
var graph: VoxelGeneratorGraph
var lakes: Array[Dictionary] = []
var river: Dictionary = {}
var village_candidates: Array[Dictionary] = []
var metadata: Dictionary = {}
var _height_image: Image
var _span := Vector2.ZERO
var _seed_rng := RandomNumberGenerator.new()

func _init(seed_value: int = 424242) -> void:
	super(seed_value)
	generation_version = WorldGenerationProfile.VERSION
	profile_id = WorldGenerationProfile.ID
	profile = WorldGenerationProfile.chapter1()
	radius = Vector2(profile.dimensions_m[0],profile.dimensions_m[1])*.5
	_span = radius*3.0
	_seed_rng.seed = seed_value
	var started := Time.get_ticks_msec()
	_compile()
	_bake()
	_select_lakes()
	_select_river()
	_compile()
	_bake()
	_score_villages()
	metadata = _measure()
	metadata.generation_ms = Time.get_ticks_msec()-started

func _compile() -> void:
	var builder := NativeTerrainGraph.new()
	var result := builder.build_v2(profile,world_seed,lakes,river)
	assert(result.success,str(result))
	graph = builder.generator

func _bake() -> void:
	var resolution := Vector2i((_span/float(profile.metadata_sample_m)).ceil())
	_height_image = Image.create(resolution.x,resolution.y,false,Image.FORMAT_RF)
	var basis := Basis(Vector3.RIGHT,Vector3.FORWARD,Vector3.UP)
	graph.generate_image_from_sdf(_height_image,Transform3D(basis,Vector3.ZERO),_span/WorldCoordinates.VOXEL_SIZE)

func surface_height(x: float, z: float) -> float:
	var uv := (Vector2(x,z)/_span+Vector2.ONE*.5)*Vector2(_height_image.get_size())-Vector2.ONE*.5
	var cell := Vector2i(uv.floor())
	var fraction := uv-Vector2(cell)
	cell = cell.clamp(Vector2i.ZERO,_height_image.get_size()-Vector2i(2,2))
	var a := _height_image.get_pixel(cell.x,cell.y).r
	var b := _height_image.get_pixel(cell.x+1,cell.y).r
	var c := _height_image.get_pixel(cell.x,cell.y+1).r
	var d := _height_image.get_pixel(cell.x+1,cell.y+1).r
	return -lerpf(lerpf(a,b,fraction.x),lerpf(c,d,fraction.x),fraction.y)*WorldCoordinates.VOXEL_SIZE

func top_surface(x: float, z: float) -> float:
	return surface_height(x,z)

func density(position: Vector3) -> float:
	# Sparse authoritative queries use exact native series evaluation, not the
	# lower-resolution metadata bake. Never called per production base voxel.
	var image := Image.create(1,1,false,Image.FORMAT_RF)
	graph.generate_image_from_sdf(image,Transform3D(Basis.IDENTITY,position/WorldCoordinates.VOXEL_SIZE),Vector2.ONE)
	return image.get_pixel(0,0).r*WorldCoordinates.VOXEL_SIZE

func material_for(y: float, top: float) -> int:
	if top < float(profile.biomes.beach_max_height):
		return 0
	if y < top-12:
		return 3
	return 2 if y < top-8 else 1

func forest_weight(point: Vector3) -> float:
	var radial := Vector2(point.x/radius.x,point.z/radius.y).length()
	return (1-smoothstep(.3,float(profile.biomes.forest_radius_ratio),radial))*smoothstep(22,45,Vector2(point.x,point.z).length())

func _select_lakes() -> void:
	var config: Dictionary = profile.lakes
	var count := _seed_rng.randi_range(int(config.count[0]),int(config.count[1]))
	for index: int in count:
		for attempt: int in 96:
			var angle := _seed_rng.randf_range(-PI,PI)
			var distance := _seed_rng.randf_range(.35,.73)
			var point := Vector2(cos(angle)*radius.x,sin(angle)*radius.y)*distance
			var height := top_surface(point.x,point.y)
			if height < 7 or lakes.any(func(row: Dictionary) -> bool: return Vector2(row.center[0],row.center[1]).distance_to(point) < 120):
				continue
			var r := _seed_rng.randf_range(config.radius_m[0],config.radius_m[1])
			lakes.append({"id":"lake_v2_%d"%index,"index":index,"center":[point.x,point.y],"radii":[r,r*_seed_rng.randf_range(.65,1.1)],
				"radius":r,"level":height-.7,"depth":float(profile.elevation_step)*_seed_rng.randi_range(config.depth_levels[0],config.depth_levels[1])})
			break

func _select_river() -> void:
	if _seed_rng.randf() > float(profile.river.probability):
		return
	# Descent search on the native macro field, then connect monotonically to sea.
	# Direction preference prevents local noise loops; every step lowers the bank.
	var best := Vector2.ZERO
	var best_height := -INF
	for candidate: int in 36:
		var angle := _seed_rng.randf_range(-PI,PI)
		var distance := _seed_rng.randf_range(.25,.48)
		var candidate_point := Vector2(cos(angle)*radius.x,sin(angle)*radius.y)*distance
		var height := top_surface(candidate_point.x,candidate_point.y)
		if height > best_height:
			best = candidate_point
			best_height = height
	var points: Array = []
	var point := best
	var water := best_height-.8
	var step := float(profile.river.trace_step_m)
	var visited: Dictionary = {}
	for segment: int in int(profile.river.max_segments):
		points.append([point.x,maxf(0,water),point.y])
		if top_surface(point.x,point.y) <= .4:
			break
		visited[Vector2i((point/step).round())] = true
		var next := point
		var score := INF
		for direction: int in 16:
			var angle := direction*TAU/16
			var candidate := point+Vector2(cos(angle),sin(angle))*step
			if visited.has(Vector2i((candidate/step).round())):
				continue
			var height := top_surface(candidate.x,candidate.y)
			var outward := (candidate/radius).length()-(point/radius).length()
			var rank := height-outward*12
			if height <= water+1.2 and rank < score:
				score = rank
				next = candidate
		if next == point:
			break
		point = next
		water = minf(water,top_surface(point.x,point.y)-.5)
	if points.size() >= 5 and top_surface(point.x,point.y) <= .4:
		river = {"id":"river_v2_0","points":points,"width":_seed_rng.randf_range(profile.river.width_m[0],profile.river.width_m[1]),"depth":float(profile.elevation_step),"reaches_sea":true}

func water_distance(point: Vector2) -> float:
	var distance := maxf(0,(1-(point/radius).length())*minf(radius.x,radius.y))
	for body: Dictionary in lakes:
		distance = minf(distance,absf(point.distance_to(Vector2(body.center[0],body.center[1]))-float(body.radius)))
	for sample: Array in river.get("points",[]):
		distance = minf(distance,point.distance_to(Vector2(sample[0],sample[2])))
	return distance

func water_at(point: Vector2) -> Dictionary:
	for body: Dictionary in lakes:
		var local := (point-Vector2(body.center[0],body.center[1]))/Vector2(body.radii[0],body.radii[1])
		if local.length() < 1.5:
			return {"kind":"lake","level":body.level}
	var samples: Array = river.get("points",[])
	for index: int in range(maxi(0,samples.size()-1)):
		var a: Array = samples[index]
		var b: Array = samples[index+1]
		var start := Vector2(a[0],a[2])
		var direction := Vector2(b[0],b[2])-start
		var t := clampf((point-start).dot(direction)/maxf(.01,direction.length_squared()),0,1)
		if point.distance_to(start+direction*t) < float(river.width)*1.4:
			return {"kind":"river","level":lerpf(a[1],b[1],t)}
	return {"kind":"ocean","level":0.0}

func lake_body() -> Dictionary:
	if lakes.is_empty():
		return {"id":"none","center":Vector2.ZERO,"radius":0.0,"level":0.0}
	var body := lakes[0].duplicate(true)
	body.center = Vector2(body.center[0],body.center[1])
	return body

func _score_villages() -> void:
	var spacing := float(profile.village.candidate_spacing_m)
	for z: int in range(-int(radius.y/spacing),int(radius.y/spacing)):
		for x: int in range(-int(radius.x/spacing),int(radius.x/spacing)):
			var point := Vector2(x,z)*spacing
			var distance := water_distance(point)
			if distance < float(profile.village.minimum_water_distance_m):
				continue
			var patch := _village_patch(point)
			if patch.is_empty():
				continue
			patch.id = "v2:%d:%d:%d"%[world_seed,x,z]
			patch.center = [point.x,top_surface(point.x,point.y),point.y]
			patch.water_distance = distance
			patch.coast_distance = maxf(0,(1-(point/radius).length())*minf(radius.x,radius.y))
			patch.score = float(patch.flatness)*.5+minf(1,float(patch.contiguous_area_m2)/1600)*.25+clampf(1-distance/200,0,1)*.25-float(patch.flood_risk)
			village_candidates.append(patch)
	village_candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.score > b.score)

func _measure() -> Dictionary:
	var land := 0
	var low := 0
	var high := 0
	var min_point := Vector2(INF,INF)
	var max_point := Vector2(-INF,-INF)
	for z: int in range(-int(radius.y),int(radius.y)+1,16):
		for x: int in range(-int(radius.x),int(radius.x)+1,16):
			var top := top_surface(x,z)
			if top > .4:
				land += 1
				low += int(top < float(profile.lowland_height)+float(profile.elevation_step))
				high += int(top >= float(profile.lowland_height)+float(profile.elevation_step))
				min_point = min_point.min(Vector2(x,z))
				max_point = max_point.max(Vector2(x,z))
	return {"seed":world_seed,"generation_version":2,"profile":profile.profile_id,"native_class":graph.get_class(),
		"land_area_m2":land*256,"land_span_m":max_point-min_point,"lowland_ratio":float(low)/maxi(1,land),"highland_ratio":float(high)/maxi(1,land),
		"lakes":lakes.duplicate(true),"river":river.duplicate(true),"village_candidates":village_candidates.size(),"height_bake_size":_height_image.get_size()}

func _village_patch(center: Vector2) -> Dictionary:
	var config: Dictionary = profile.village
	var width := float(config.footprint_m)
	var spacing := width/8
	var heights: Dictionary = {}
	var eligible: Dictionary = {}
	var highest := -INF
	var lowest := INF
	var max_slope := 0.0
	var flooded := 0
	for z: int in 8:
		for x: int in 8:
			var cell := Vector2i(x,z)
			var point := center+(Vector2(cell)-Vector2.ONE*3.5)*spacing
			var height := top_surface(point.x,point.y)
			heights[cell] = height
			highest = maxf(highest,height)
			lowest = minf(lowest,height)
			var water := water_at(point)
			if height <= float(water.level)+1:
				flooded += 1
			elif height >= float(config.minimum_height_m):
				eligible[cell] = true
	for cell: Vector2i in eligible.keys():
		var slope := 0.0
		for direction: Vector2i in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
			if heights.has(cell+direction):
				slope = maxf(slope,rad_to_deg(atan(absf(float(heights[cell])-float(heights[cell+direction]))/spacing)))
		max_slope = maxf(max_slope,slope)
		if slope > float(config.max_slope_degrees):
			eligible.erase(cell)
	var largest := 0
	while not eligible.is_empty():
		var queue: Array = [eligible.keys()[0]]
		var size := 0
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_back()
			if not eligible.has(cell):
				continue
			eligible.erase(cell)
			size += 1
			for direction: Vector2i in [Vector2i.RIGHT,Vector2i.LEFT,Vector2i.UP,Vector2i.DOWN]:
				if eligible.has(cell+direction):
					queue.append(cell+direction)
		largest = maxi(largest,size)
	var area := largest*spacing*spacing
	if area < 1200 or highest-lowest > 4 or max_slope > float(config.max_slope_degrees) or flooded > 0:
		return {}
	return {"flatness":clampf(1-(highest-lowest)/4,0,1),"contiguous_area_m2":area,"steepness_degrees":max_slope,"flood_risk":float(flooded)/64}
