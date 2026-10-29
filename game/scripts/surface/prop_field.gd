class_name PropField
extends RefCounted
## Pure deterministic candidate strata, independent of presentation/stream order.
const PATCH := 16.0
var field: IslandField
func _init(source: IslandField) -> void:
	field = source

func biome(point: Vector3) -> String:
	if point.y < 5.0:
		return "BEACH"
	if field.forest_weight(point) > 0.32:
		return "CENTRAL_FOREST"
	return "TROPICAL_HILLS" if point.y > 17.0 else "TROPICAL_PLAINS"

func candidates(patch: Vector2i) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for definition: Dictionary in SurfaceCatalog.data().props:
		var rng := RandomNumberGenerator.new()
		rng.seed = (str(field.world_seed)+":1:"+str(patch)+":"+definition.id).hash()
		var cluster := Vector2.ZERO
		for index: int in int(definition.density):
			if index % int(definition.cluster_count) == 0:
				cluster = Vector2(rng.randf_range(0,PATCH),rng.randf_range(0,PATCH))
			var local := cluster
			if int(definition.cluster_count) > 1:
				local += Vector2(rng.randf_range(-definition.cluster_radius,definition.cluster_radius),rng.randf_range(-definition.cluster_radius,definition.cluster_radius))
			var x := patch.x*PATCH+clampf(local.x,0.1,PATCH-.1)
			var z := patch.y*PATCH+clampf(local.y,0.1,PATCH-.1)
			var y := field.top_surface(x,z)
			if not is_finite(y) or y < definition.min_height or y > definition.max_height:
				continue
			var point := Vector3(x,y,z)
			var coast_distance := maxf(0,(1.0-Vector2(x/field.radius.x,z/field.radius.y).length())*minf(field.radius.x,field.radius.y))
			var water_distance := minf(coast_distance,absf(Vector2(x+72,z-48).length()-15.0))
			if water_distance < definition.distance_to_water[0] or water_distance > definition.distance_to_water[1]:
				continue
			var region := biome(point)
			var material := field.material_at(point)
			if region not in definition.biomes or not definition.materials.any(func(value: Variant) -> bool: return int(value) == material):
				continue
			var dx := field.top_surface(x+0.5,z)-field.top_surface(x-0.5,z)
			var dz := field.top_surface(x,z+0.5)-field.top_surface(x,z-0.5)
			if rad_to_deg(atan(Vector2(dx,dz).length())) > definition.max_slope or rng.randf() > definition.rarity:
				continue
			if Vector2(x+72,z-48).length() < 16 or Vector2(x,z).length() < 3:
				continue # Spawn corridor and sleeping lake exclusion.
			result.append({"id":"p1:%d:%d:%d:%s:%d" % [field.world_seed,patch.x,patch.y,definition.id,index],
				"definition":definition.id,"point":[x,y,z],"yaw":rng.randf_range(-PI,PI),"scale":rng.randf_range(0.85,1.15),"biome":region})
	return result
