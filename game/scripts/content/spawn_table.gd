class_name SpawnTable
extends RefCounted
## Pure data, private seeded RNG. Existing legacy spawn decisions stay unchanged.
var tables: Array = []
func _init() -> void:
	tables = ContentData.rows("spawn_tables")
func entries(table: Dictionary, domain: String) -> Array:
	return table.get("entries",[]).filter(func(row: Dictionary) -> bool: return row.domain == domain)
func choose(candidates: Array, rng: RandomNumberGenerator) -> Dictionary:
	var total := 0.0
	for row: Dictionary in candidates: total += float(row.weight)
	if total <= 0: return {}
	var target := rng.randf()*total
	for row: Dictionary in candidates:
		target -= float(row.weight)
		if target <= 0: return row
	return candidates.back()
func candidates(field: IslandField, patch: Vector2i, biome_query: Callable, domain: String = "SURFACE") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
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
				if entry.get("conditions",{}).get("dry_land",true) and y < 0: continue
				eligible.append(entry)
			var selected := choose(eligible,rng)
			if selected.is_empty(): continue
			result.append({"id":"pc%d:%d:%d:%d:%s:%s:%d"%[int(table.version),field.world_seed,patch.x,patch.y,table.id,selected.id,index],"definition":selected.prop_definition,"point":[x,y,z],"yaw":rng.randf_range(-PI,PI),"scale":rng.randf_range(.85,1.15),"biome":region,"domain":domain})
	return result
