class_name EffectGraph
extends RefCounted
## Bounded compiled DAGs, no SceneTree objects per effect node.
static var _cache: Dictionary = {}
static var _revision := -1
static var compilations := 0
static func compile(id: String) -> Dictionary:
	if _revision != ContentData.revision:
		_cache.clear()
		_revision = ContentData.revision
	if _cache.has(id): return _cache[id]
	var data := ContentData.find("effects",id)
	if data.is_empty(): return {}
	var items := {}
	for row: Dictionary in ContentData.rows("items"): items[row.id] = true
	var issues: Array = []
	ContentValidator.validate_graph(data,{"items":items},issues)
	if ContentValidator.has_errors(issues) or not ContentValidator._safe_data(data): return {}
	var nodes := {}
	for row: Dictionary in data.nodes: nodes[row.id] = row.duplicate(true)
	_cache[id] = {"nodes":nodes,"triggers":data.triggers.duplicate(),"inventory":nodes.values().any(func(row: Dictionary) -> bool: return row.type in ["GiveItem","RemoveItem"])}
	compilations += 1
	return _cache[id]
static func prepare(id: String, trigger: String, context: EffectContext) -> Error:
	var graph := compile(id)
	if graph.is_empty(): return ERR_INVALID_DATA
	if not graph.triggers.has(trigger): return OK
	var pending: Array = [graph.triggers[trigger]]
	var visited := {}
	while not pending.is_empty():
		var key: String = pending.pop_front()
		if visited.has(key): continue
		visited[key] = true
		var node: Dictionary = graph.nodes[key]
		match node.type:
			"CheckCondition":
				var valid := false
				match node.condition:
					"target_has_tag": valid = node.tag in context.tags
					"player_health_below": valid = float(context.stats.health) < float(node.threshold)
					"random_chance": valid = context.rng.randf() < float(node.chance)
				if not valid: continue
			"Damage": context.damage += context.damage_input if node.get("use_weapon_damage",false) else float(node.amount)
			"ModifyStat": context.stats[node.stat] = clampf(float(context.stats.get(node.stat,0))+float(node.amount),0,float(context.maxima.get(node.stat,100)))
			"GiveItem":
				if context.inventory == null: return ERR_UNAVAILABLE
				InventoryCommands.output(context.inventory,node.item_id,int(node.quantity))
			"RemoveItem":
				if context.inventory == null: return ERR_UNAVAILABLE
				var left := int(node.quantity)
				for index: int in InventoryState.CAPACITY:
					var stack := context.inventory._slots[index]
					if stack != null and stack.item_id == node.item_id:
						var amount := mini(left,stack.quantity)
						context.inventory.consume_uid(stack.stack_uid,amount)
						left -= amount
				if left > 0: return ERR_UNAVAILABLE
			"ApplyStatus","SpawnEntity","PlayEffect": context.events.append(node.duplicate(true))
		pending.append_array(node.get("next",[]))
	return OK
