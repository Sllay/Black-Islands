class_name SpawnTable
extends RefCounted
## Pure data, private seeded RNG. Existing legacy spawn decisions stay unchanged.
var tables: Array = []
func _init() -> void:
	tables = ContentData.rows("spawn_tables")
func entries(table: Dictionary, domain: String) -> Array:
	return table.get("entries",[]).filter(func(row: Dictionary) -> bool: return row.domain == domain)
func choose(pool: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for row: Dictionary in pool: total += float(row.weight)
	if total <= 0: return {}
	var target := rng.randf()*total
	for row: Dictionary in pool:
		target -= float(row.weight)
		if target <= 0: return row
	return pool.back()
func candidates(field: IslandField, patch: Vector2i, biome_query: Callable, domain: String = "SURFACE") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not field is WorldFieldV2: return result # Legacy saves keep legacy placement.
	for table: Dictionary in tables:
		var options := entries(table,domain)
		if options.is_empty(): continue
		var rng := RandomNumberGenerator.new()
		rng.seed = (str(field.world_seed)+":"+str(patch)+":"+table.id+":"+str(table.version)).hash()
		for index: int in int(table.get("density",2)):
			var x := patch.x*16.0+rng.randf_range(.5,15.5)
			var z := patch.y*16.0+rng.randf_range(.5,15.5)
			var y := field.top_surface(x,z)
			if not is_finite(y) or Vector2(x,z).length() < 3: continue
			var point := Vector3(x,y,z)
			var region: String = biome_query.call(point)
			var material := field.material_at(point)
			var dx := field.top_surface(x+.5,z)-field.top_surface(x-.5,z)
			var dz := field.top_surface(x,z+.5)-field.top_surface(x,z-.5)
			var slope := rad_to_deg(atan(Vector2(dx,dz).length()))
			var distance: float = field.water_distance(Vector2(x,z)) if field is WorldFieldV2 else maxf(0,field.radius.x-Vector2(x,z).length())
			var eligible: Array = []
			for entry: Dictionary in options:
				if y < float(entry.get("min_height",0)) or y > float(entry.get("max_height",100)) or slope < float(entry.get("min_slope",0)) or slope > float(entry.get("max_slope",35)): continue
				if region not in entry.get("biomes",[region]) or not entry.get("materials",[material]).any(func(value: Variant) -> bool: return int(value) == material): continue
				var water: Array = entry.get("water_distance",[0,10000])
				if distance < float(water[0]) or distance > float(water[1]): continue
				if entry.get("conditions",{}).get("dry_land",true) and y < float(field.water_at(Vector2(x,z)).level)+.1: continue
				eligible.append(entry)
			var selected := choose(eligible,rng)
			if selected.is_empty(): continue
			var cluster: Dictionary = selected.get("cluster",{"count":1,"radius":0})
			for child: int in int(cluster.get("count",1)):
				var location := point
				if child > 0:
					location.x += rng.randf_range(-float(cluster.radius),float(cluster.radius))
					location.z += rng.randf_range(-float(cluster.radius),float(cluster.radius))
					location.y = field.top_surface(location.x,location.z)
					if not is_finite(location.y): continue
					var wet_level := float(field.water_at(Vector2(location.x,location.z)).level)
					if selected.get("conditions",{}).get("dry_land",true) and location.y < wet_level+.1: continue
					if location.y < float(selected.min_height) or location.y > float(selected.max_height): continue
					if biome_query.call(location) not in selected.biomes or not selected.materials.any(func(value: Variant) -> bool: return int(value) == field.material_at(location)): continue
					var sx := field.top_surface(location.x+.5,location.z)-field.top_surface(location.x-.5,location.z)
					var sz := field.top_surface(location.x,location.z+.5)-field.top_surface(location.x,location.z-.5)
					var child_slope := rad_to_deg(atan(Vector2(sx,sz).length()))
					var child_water: float = field.water_distance(Vector2(location.x,location.z))
					if child_slope < float(selected.min_slope) or child_slope > float(selected.max_slope) or child_water < float(selected.water_distance[0]) or child_water > float(selected.water_distance[1]): continue
				var identity := "pc%d:%d:%d:%d:%s:%s:%d"%[int(table.version),field.world_seed,patch.x,patch.y,table.id,selected.id,index]
				if child > 0: identity += ":c%d"%child
				result.append({"id":identity,"definition":selected.prop_definition,"point":[location.x,location.y,location.z],"yaw":rng.randf_range(-PI,PI),"scale":rng.randf_range(.85,1.15),"biome":region,"domain":domain})
	return result
