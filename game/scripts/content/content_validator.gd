@tool
class_name ContentValidator
extends RefCounted
static func has_errors(issues: Array) -> bool:
	return issues.any(func(issue: Dictionary) -> bool: return issue.severity == "ERROR")
static func issue(issues: Array, section: String, id: String, message: String, severity: String = "ERROR") -> void:
	issues.append({"severity":severity,"section":section,"definition":id,"file":ContentData.FILES.get(ContentData.GROUPS.get(section,""),""),"message":message})
static func numeric(value: Variant, minimum: float = 0.0, maximum: float = 1.0e9) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= minimum and value <= maximum
static func validate(bundle: Dictionary) -> Array:
	var issues: Array = []
	var ids := {}
	for group: String in ContentData.FILES:
		if not bundle.get(group) is Dictionary or bundle[group].get("schema_version") != 1:
			issue(issues,group,"","Unknown/missing catalog schema")
	for section: String in ContentData.GROUPS:
		ids[section] = {}
		var records: Variant = bundle.get(ContentData.GROUPS[section],{}).get(section,[])
		if not records is Array:
			issue(issues,section,"","Expected record array")
			continue
		for row: Variant in records:
			if not row is Dictionary or not row.get("id") is String or row.id.is_empty():
				issue(issues,section,"","Missing stable ID")
				continue
			if ids[section].has(row.id):
				issue(issues,section,row.id,"Duplicate ID")
			ids[section][row.id] = row
	for id: String in ids.items:
		var row: Dictionary = ids.items[id]
		if row.get("category") not in ContentSchema.CATEGORIES or not numeric(row.get("stack_limit",row.get("max_stack",1)),1,999999):
			issue(issues,"items",id,"Invalid category/stack limit")
		var types := {}
		for module: Variant in row.get("modules",[]):
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
					if not numeric(module.get("power"),.001): issue(issues,"items",id,"Invalid harvest power")
					for resource: String in module.get("resources",{}):
						if not ids.items.has(resource): issue(issues,"items",id,"Invalid resource ID: "+resource)
			for effect: String in module.get("effects",[]):
				if not ids.effects.has(effect): issue(issues,"items",id,"Missing effect: "+effect)
	for id: String in ids.recipes:
		var row: Dictionary = ids.recipes[id]
		if not numeric(row.get("craft_duration"),.001): issue(issues,"recipes",id,"Invalid duration")
		for key: String in ["ingredients","outputs"]:
			if not row.get(key) is Array or row[key].is_empty():
				issue(issues,"recipes",id,"Missing "+key)
				continue
			for part: Variant in row[key]:
				if not part is Dictionary or not ids.items.has(part.get("item_id")) or not numeric(part.get("quantity"),1) or part.quantity != int(part.quantity): issue(issues,"recipes",id,"Invalid "+key+" reference/quantity")
	for id: String in ids.weapons:
		var row: Dictionary = ids.weapons[id]
		if row.get("weapon_class") not in ContentSchema.WEAPON_CLASSES: issue(issues,"weapons",id,"Unknown weapon class")
		if not ids.movesets.has(row.get("moveset_id")): issue(issues,"weapons",id,"Missing moveset")
		if not ids.visual_profiles.has(row.get("visual_profile_id")): issue(issues,"weapons",id,"Missing visual profile")
		for key: String in ["base_damage","attack_speed","move_modifier","knockback","crit_chance","crit_multiplier"]:
			if not numeric(row.get(key)): issue(issues,"weapons",id,"Invalid "+key)
		for effect: String in row.get("effects",[]):
			if not ids.effects.has(effect): issue(issues,"weapons",id,"Missing effect")
	for id: String in ids.visual_profiles:
		var row: Dictionary = ids.visual_profiles[id]
		if row.get("mode") not in ["LPC_LAYER","DETACHED_SPRITE"]: issue(issues,"visual_profiles",id,"Invalid visual mode")
	for id: String in ids.effects:
		validate_graph(ids.effects[id],ids,issues)
	for id: String in ids.props:
		if not ids.harvestables.has(ids.props[id].get("harvest")): issue(issues,"props",id,"Missing harvestable")
	for id: String in ids.harvestables:
		for resource: String in ids.harvestables[id].get("reserves",{}):
			if not ids.items.has(resource): issue(issues,"harvestables",id,"Invalid resource ID")
	for id: String in ids.spawn_tables:
		for entry: Dictionary in ids.spawn_tables[id].get("entries",[]):
			if not ids.props.has(entry.get("prop_definition")) or entry.get("domain") not in ["SURFACE","CAVE"] or not numeric(entry.get("weight"),.00001): issue(issues,"spawn_tables",id,"Invalid spawn entry reference/domain/weight")
	if not has_errors(issues): issue(issues,"items","","All content references valid","INFO")
	return issues
static func validate_graph(graph: Dictionary, ids: Dictionary, issues: Array) -> void:
	var nodes := {}
	var id := str(graph.id)
	for row: Variant in graph.get("nodes",[]):
		if not row is Dictionary or not row.get("id") is String or nodes.has(row.id) or row.get("type") not in ContentSchema.EFFECT_TYPES:
			issue(issues,"effects",id,"Invalid/unknown/duplicate effect node")
			continue
		nodes[row.id] = row
	for trigger: String in graph.get("triggers",{}):
		if trigger not in ContentSchema.TRIGGERS or not nodes.has(graph.triggers[trigger]): issue(issues,"effects",id,"Invalid trigger reference")
	for node_id: String in nodes:
		var row: Dictionary = nodes[node_id]
		for next: Variant in row.get("next",[]):
			if not nodes.has(next): issue(issues,"effects",id,"Missing node reference")
		match row.type:
			"Damage","ModifyStat":
				if not numeric(row.get("amount"),-100000,100000): issue(issues,"effects",id,"Missing effect amount")
			"GiveItem","RemoveItem":
				if not ids.items.has(row.get("item_id")) or not numeric(row.get("quantity"),1): issue(issues,"effects",id,"Invalid item reference")
			"CheckCondition":
				if row.get("condition") not in ["target_has_tag","player_health_below","random_chance"]: issue(issues,"effects",id,"Unknown condition")
	var visiting := {}
	var visited := {}
	for node_id: String in nodes:
		if _cycle(node_id,nodes,visiting,visited):
			issue(issues,"effects",id,"Effect graph cycle")
			break
static func _cycle(id: String, nodes: Dictionary, visiting: Dictionary, visited: Dictionary) -> bool:
	if visiting.has(id): return true
	if visited.has(id) or not nodes.has(id): return false
	visiting[id] = true
	for next: String in nodes[id].get("next",[]):
		if _cycle(next,nodes,visiting,visited): return true
	visiting.erase(id)
	visited[id] = true
	return false
