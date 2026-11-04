@tool
class_name ContentValidator
extends RefCounted
const MAX_RECORDS := 4096
const MAX_NODES := 256
const MAX_EDGES := 1024
static func has_errors(issues: Array) -> bool:
	return issues.any(func(row: Dictionary) -> bool: return row.severity == "ERROR")
static func issue(issues: Array, section: String, id: String, message: String, severity: String = "ERROR") -> void:
	issues.append({"severity":severity,"section":section,"definition":id,"file":ContentData.FILES.get(ContentData.GROUPS.get(section,""),""),"message":message})
static func numeric(value: Variant, minimum: float = 0.0, maximum: float = 1.0e9) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum
static func integer(value: Variant, minimum: int = 1, maximum: int = 999999) -> bool:
	return numeric(value,minimum,maximum) and value == int(value)
static func array(value: Variant) -> Array:
	return value if value is Array else []
static func dict(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}
static func records(bundle: Dictionary, section: String) -> Array:
	return array(dict(bundle.get(ContentData.GROUPS[section])).get(section))
static func validate(bundle: Dictionary) -> Array:
	var issues: Array = []
	var ids := {}
	var global_ids := {}
	for group: String in ContentData.FILES:
		if not bundle.get(group) is Dictionary or bundle[group].get("schema_version") != 1:
			issue(issues,group,"","Unknown/missing catalog schema")
	for section: String in ContentData.GROUPS:
		ids[section] = {}
		var raw: Variant = dict(bundle.get(ContentData.GROUPS[section])).get(section,[])
		if not raw is Array or raw.size() > MAX_RECORDS:
			issue(issues,section,"","Invalid/oversized record array")
			continue
		for value: Variant in raw:
			if not value is Dictionary or not value.get("id") is String or value.id.is_empty():
				issue(issues,section,"","Missing stable ID")
				continue
			var id: String = value.id
			if global_ids.has(id): issue(issues,section,id,"Duplicate ID across catalog")
			global_ids[id] = section
			if ids[section].has(id): issue(issues,section,id,"Duplicate ID")
			ids[section][id] = value
			if not _safe_data(value): issue(issues,section,id,"Executable/oversized content data blocked")
	for id: String in ids.items:
		var row: Dictionary = ids.items[id]
		if row.get("category") not in ContentSchema.CATEGORIES or not integer(row.get("stack_limit",row.get("max_stack",1))): issue(issues,"items",id,"Invalid category/stack limit")
		if not row.get("modules",[]) is Array: issue(issues,"items",id,"Invalid module array")
		var types := {}
		for module: Variant in array(row.get("modules",[])):
			if not module is Dictionary or not ContentSchema.MODULES.has(module.get("type")):
				issue(issues,"items",id,"Unknown item module")
				continue
			if types.has(module.type): issue(issues,"items",id,"Duplicate item module")
			types[module.type] = true
			match module.type:
				"SpoilageModule":
					if not numeric(module.get("duration"),.001) or not ids.items.has(module.get("result_item_id")): issue(issues,"items",id,"Invalid spoilage result/duration")
				"WeaponModule":
					if not ids.weapons.has(module.get("weapon_id")): issue(issues,"items",id,"Missing weapon")
				"HarvestToolModule":
					for tag: Variant in dict(module.get("targets")):
						if tag not in ["ROCK","TREE","CORPSE"]: issue(issues,"items",id,"Invalid harvest target tag")
					if not numeric(module.get("power"),.001) or not module.get("resources",{}) is Dictionary or not module.get("targets",{}) is Dictionary: issue(issues,"items",id,"Invalid harvest profile")
					for resource: Variant in dict(module.get("resources")):
						if not ids.items.has(resource) or not numeric(module.resources[resource]): issue(issues,"items",id,"Invalid resource ID/affinity")
					for key: String in ["efficiency","quality_power","quality_yield","stamina"]:
						if not numeric(module.get(key,1.0 if key != "efficiency" else null),0,10000): issue(issues,"items",id,"Invalid harvest "+key)
					for affinity: Variant in dict(module.get("targets")).values():
						if not numeric(affinity,0,10000): issue(issues,"items",id,"Invalid target affinity")
					if not numeric(module.get("critical_chance",0),0,1) or not numeric(module.get("critical_multiplier",1.5),1,100): issue(issues,"items",id,"Invalid harvest critical range")
				"WaterContainerModule":
					if not numeric(module.get("capacity"),.001) or not numeric(module.get("watering_cost"),.001): issue(issues,"items",id,"Invalid water capacity/cost")
				"ProjectileModule":
					if not numeric(module.get("speed"),.001,10000): issue(issues,"items",id,"Invalid projectile speed")
				"BuildingItemModule":
					if not module.get("definition_id") is String or module.definition_id.is_empty(): issue(issues,"items",id,"Missing building identity")
				"ConsumableModule":
					if module.get("legacy_effect","") not in ["","restore_health","restore_stamina"] or not numeric(module.get("amount",0)): issue(issues,"items",id,"Invalid consumable config")
			if not module.get("effects",[]) is Array: issue(issues,"items",id,"Invalid effect reference array")
			for effect: Variant in array(module.get("effects",[])):
				if not ids.effects.has(effect): issue(issues,"items",id,"Missing effect")
	for id: String in ids.recipes:
		var row: Dictionary = ids.recipes[id]
		if not numeric(row.get("craft_duration"),.001): issue(issues,"recipes",id,"Invalid duration")
		for key: String in ["ingredients","outputs"]:
			if not row.get(key) is Array or row[key].is_empty(): issue(issues,"recipes",id,"Missing "+key)
			for part: Variant in array(row.get(key)):
				if not part is Dictionary or not ids.items.has(part.get("item_id")) or not integer(part.get("quantity")): issue(issues,"recipes",id,"Invalid "+key+" reference/quantity")
	for id: String in ids.weapons:
		var row: Dictionary = ids.weapons[id]
		if row.get("weapon_class") not in ContentSchema.WEAPON_CLASSES: issue(issues,"weapons",id,"Unknown weapon class")
		if not ids.movesets.has(row.get("moveset_id")): issue(issues,"weapons",id,"Missing moveset")
		if not ids.visual_profiles.has(row.get("visual_profile_id")): issue(issues,"weapons",id,"Missing visual profile")
		for key: String in ["base_damage","attack_speed","move_modifier","knockback","crit_chance","crit_multiplier"]:
			if not numeric(row.get(key)): issue(issues,"weapons",id,"Invalid "+key)
		if not numeric(row.get("crit_chance"),0,1) or not numeric(row.get("attack_speed"),.01,10): issue(issues,"weapons",id,"Invalid critical/speed range")
		for effect: Variant in array(row.get("effects",[])):
			if not ids.effects.has(effect): issue(issues,"weapons",id,"Missing effect")
	for id: String in ids.movesets:
		if ids.movesets[id].get("template_id") != "sword.training.v1": issue(issues,"movesets",id,"Unknown reviewed moveset template")
	for id: String in ids.visual_profiles:
		validate_visual(ids.visual_profiles[id],issues)
	for id: String in ids.effects: validate_graph(ids.effects[id],ids,issues)
	for id: String in ids.props:
		if not ids.harvestables.has(ids.props[id].get("harvest")): issue(issues,"props",id,"Missing harvestable")
		var visual := dict(ids.props[id].get("visual"))
		if visual.get("kind") not in ["BOULDER","MINERAL_ROOT"] or not visual.get("color") is String or not Color.html_is_valid(visual.color): issue(issues,"props",id,"Invalid prop visual/material")
		if visual.get("kind") == "MINERAL_ROOT" and (not visual.get("ore_color") is String or not Color.html_is_valid(visual.ore_color)): issue(issues,"props",id,"Invalid ore material")
	for id: String in ids.harvestables:
		if ids.harvestables[id].get("tag") not in ["ROCK","TREE","CORPSE"]: issue(issues,"harvestables",id,"Invalid harvest target tag")
		if not numeric(ids.harvestables[id].get("health"),.001,100000) or not numeric(ids.harvestables[id].get("resistance",0)): issue(issues,"harvestables",id,"Invalid health/resistance")
		if not ids.harvestables[id].get("reserves") is Dictionary: issue(issues,"harvestables",id,"Invalid reserves")
		for resource: Variant in dict(ids.harvestables[id].get("reserves")):
			if not ids.items.has(resource) or not integer(ids.harvestables[id].reserves[resource],0): issue(issues,"harvestables",id,"Invalid resource ID/reserve")
	for id: String in ids.spawn_tables:
		var table: Dictionary = ids.spawn_tables[id]
		if not integer(table.get("version"),1,1) or not integer(table.get("density"),1,64) or not table.get("entries") is Array or table.entries.is_empty() or table.entries.size() > 128: issue(issues,"spawn_tables",id,"Invalid table version/density/entries")
		var entries := {}
		for entry: Variant in array(table.get("entries")):
			if not entry is Dictionary:
				issue(issues,"spawn_tables",id,"Invalid spawn entry")
				continue
			if not entry.get("id") is String or entries.has(entry.get("id")): issue(issues,"spawn_tables",id,"Invalid/duplicate entry ID")
			entries[entry.get("id")] = true
			if not ids.props.has(entry.get("prop_definition")) or entry.get("domain") not in ["SURFACE","CAVE"] or not numeric(entry.get("weight"),.00001): issue(issues,"spawn_tables",id,"Invalid spawn reference/domain/weight")
			var cluster := dict(entry.get("cluster"))
			if not integer(cluster.get("count"),1,8) or not numeric(cluster.get("radius"),0,8): issue(issues,"spawn_tables",id,"Invalid bounded cluster")
			if entry.get("rarity") not in ["Common","Uncommon","Rare","VeryRare"]: issue(issues,"spawn_tables",id,"Invalid rarity tier")
			if not vector2(entry.get("water_distance")) or float(entry.water_distance[0]) > float(entry.water_distance[1]): issue(issues,"spawn_tables",id,"Invalid water-distance filter")
			for key: String in ["min_height","max_height","min_slope","max_slope"]:
				if not numeric(entry.get(key),-1000,1000): issue(issues,"spawn_tables",id,"Invalid terrain filter")
			if not entry.get("biomes") is Array or not entry.get("materials") is Array: issue(issues,"spawn_tables",id,"Invalid biome/material filter")
	if not has_errors(issues): issue(issues,"items","","All content references valid","INFO")
	return issues
static func _safe_data(value: Variant) -> bool:
	var pending: Array = [value]
	var visited := 0
	while not pending.is_empty():
		visited += 1
		if visited > 20000: return false
		var item: Variant = pending.pop_back()
		if item is Dictionary:
			for key: Variant in item:
				if key in ["script_path","execute","expression","script","callable"]: return false
				pending.append(item[key])
		elif item is Array: pending.append_array(item)
	return true
static func validate_graph(graph: Dictionary, ids: Dictionary, issues: Array) -> void:
	var id := str(graph.get("id",""))
	if not graph.get("nodes") is Array or graph.nodes.is_empty() or graph.nodes.size() > MAX_NODES or not graph.get("triggers") is Dictionary:
		issue(issues,"effects",id,"Invalid graph shape/size")
		return
	var nodes := {}
	var degrees := {}
	var edges := 0
	for row: Variant in graph.nodes:
		if not row is Dictionary or not row.get("id") is String or row.id.is_empty() or nodes.has(row.id) or row.get("type") not in ContentSchema.EFFECT_TYPES or not row.get("next",[]) is Array or row.get("next",[]).size() > 16:
			issue(issues,"effects",id,"Invalid/unknown/duplicate effect node")
			continue
		nodes[row.id] = row
		degrees[row.id] = 0
	for trigger: Variant in graph.triggers:
		if trigger not in ContentSchema.TRIGGERS or not nodes.has(graph.triggers[trigger]): issue(issues,"effects",id,"Invalid trigger reference")
	for node_id: String in nodes:
		var row: Dictionary = nodes[node_id]
		for next: Variant in row.get("next",[]):
			edges += 1
			if not next is String or not nodes.has(next): issue(issues,"effects",id,"Missing node reference")
			else: degrees[next] += 1
		match row.type:
			"Damage":
				if not numeric(row.get("amount"),0,100000): issue(issues,"effects",id,"Invalid damage amount")
			"ModifyStat":
				if row.get("stat") not in ["health","stamina","mana"] or not numeric(row.get("amount"),-100000,100000): issue(issues,"effects",id,"Invalid stat/amount")
			"GiveItem","RemoveItem":
				if not dict(ids.get("items")).has(row.get("item_id")) or not integer(row.get("quantity")): issue(issues,"effects",id,"Invalid item reference/quantity")
			"ApplyStatus":
				if row.get("status_id") != "bi.status.fire.test" or not numeric(row.get("duration"),.001,600): issue(issues,"effects",id,"Invalid registered status/duration")
			"SpawnEntity":
				if row.get("entity_id") != "bi.entity.qa_spark": issue(issues,"effects",id,"Invalid registered entity")
			"PlayEffect":
				if row.get("effect_id") != "bi.vfx.hit.test": issue(issues,"effects",id,"Invalid registered presentation effect")
			"CheckCondition":
				if row.get("condition") not in ["target_has_tag","player_health_below","random_chance"]: issue(issues,"effects",id,"Unknown condition")
				elif row.condition == "target_has_tag" and (not row.get("tag") is String or row.tag.is_empty()): issue(issues,"effects",id,"Missing condition tag")
				elif row.condition == "player_health_below" and not numeric(row.get("threshold"),0,100000): issue(issues,"effects",id,"Invalid health threshold")
				elif row.condition == "random_chance" and not numeric(row.get("chance"),0,1): issue(issues,"effects",id,"Invalid probability")
	if edges > MAX_EDGES: issue(issues,"effects",id,"Too many graph edges")
	var ready: Array[String] = []
	var depth := {}
	for key: String in degrees:
		if degrees[key] == 0: ready.append(key)
	var seen := 0
	while not ready.is_empty():
		var current := ready.pop_back() as String
		seen += 1
		if int(depth.get(current,0)) > 64: issue(issues,"effects",id,"Graph depth exceeds64")
		for next: Variant in nodes[current].get("next",[]):
			if degrees.has(next):
				degrees[next] -= 1
				depth[next] = maxi(int(depth.get(next,0)),int(depth.get(current,0))+1)
				if degrees[next] == 0: ready.append(next)
	if seen != nodes.size(): issue(issues,"effects",id,"Effect graph cycle")

static func validate_visual(row: Dictionary, issues: Array) -> void:
	var id := str(row.id)
	if row.get("mode") == "LPC_LAYER":
		if row.get("lpc_asset_id") != "lpc.weapon.sword": issue(issues,"visual_profiles",id,"Missing accepted LPC weapon asset")
		return
	if row.get("mode") != "DETACHED_SPRITE":
		issue(issues,"visual_profiles",id,"Invalid visual mode")
		return
	for key: String in ["idle_texture","attack_texture"]:
		if not texture_path(row.get(key)): issue(issues,"visual_profiles",id,"Invalid image resource "+key)
	if not vector2(row.get("pivot")): issue(issues,"visual_profiles",id,"Invalid pivot")
	for key: String in ["rotation_curve","position_curve","scale_curve"]:
		var points: Variant = row.get(key)
		if not points is Array or points.is_empty() or points.size() > 16:
			issue(issues,"visual_profiles",id,"Invalid bounded curve "+key)
			continue
		var last := -1.0
		for point: Variant in points:
			if not vector2(point) or not numeric(point[0],0,1) or float(point[0]) < last or not numeric(point[1],.01 if key == "scale_curve" else -720.0,720): issue(issues,"visual_profiles",id,"Invalid curve point")
			else: last = float(point[0])
	for direction: String in ["north","west","south","east"]:
		if not vector2(dict(row.get("direction_offsets")).get(direction)): issue(issues,"visual_profiles",id,"Missing direction offset")
		if dict(row.get("layer_behavior")).get(direction) not in ["FRONT_CHARACTER","BEHIND_CHARACTER"]: issue(issues,"visual_profiles",id,"Invalid semantic layer")
	var trail := dict(row.get("trail_profile"))
	if not numeric(trail.get("width"),.001,2) or not numeric(trail.get("duration"),.001,1): issue(issues,"visual_profiles",id,"Invalid trail profile")
	if not str(trail.get("texture","")).is_empty() and not texture_path(trail.texture): issue(issues,"visual_profiles",id,"Invalid trail texture")
static func vector2(value: Variant) -> bool:
	return value is Array and value.size() == 2 and numeric(value[0],-10000,10000) and numeric(value[1],-10000,10000)
static func texture_path(value: Variant) -> bool:
	return value is String and value.begins_with("res://assets/") and value.get_extension() in ["png","svg","webp"] and FileAccess.file_exists(value)
