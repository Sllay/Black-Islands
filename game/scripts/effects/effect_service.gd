class_name EffectService
extends RefCounted
## Transaction adapter. Graph only prepares values, payment and semantic events.
static var status_events: Array[Dictionary] = []
static var spawn_hook: Callable
static var presentation_hook: Callable
static func context_for(actor: PlayerActor, inventory: InventoryState, event_key: String = "") -> EffectContext:
	var context := EffectContext.new()
	context.inventory = inventory
	context.stats = {"health":actor.state.current_health,"stamina":actor.state.current_stamina,"mana":100.0}
	context.maxima = {"health":actor.state.max_health,"stamina":actor.state.max_stamina,"mana":100.0}
	context.rng.seed = (actor.inventory.state.inventory_id+":"+str(actor.inventory.state.revision)+":"+event_key).hash()
	return context
static func publication(actor: PlayerActor, context: EffectContext) -> InventoryPublication:
	var before := {"health":actor.state.current_health,"stamina":actor.state.current_stamina}
	var result := InventoryPublication.new()
	result.validate = func() -> bool: return is_instance_valid(actor) and actor.state.current_health == before.health and actor.state.current_stamina == before.stamina
	result.apply = func() -> void:
		if context.stats.health != before.health: actor.state.set_health(context.stats.health)
		if context.stats.stamina != before.stamina: actor.state.set_stamina(context.stats.stamina)
	result.notify = func() -> void:
		for event: Dictionary in context.events:
			match event.type:
				"ApplyStatus":
					status_events.append({"status_id":event.status_id,"duration":event.duration})
					if status_events.size() > 32: status_events.pop_front()
				"SpawnEntity":
					if spawn_hook.is_valid(): spawn_hook.call(event.entity_id,actor.global_position)
				"PlayEffect":
					if presentation_hook.is_valid(): presentation_hook.call(event.effect_id,actor.global_position)
	return result
static func consume(actor: PlayerActor, source: InventoryState, uid: String, revision: int, graphs: Array) -> InventoryPlan:
	var plan := InventoryPlan.new()
	var copy := plan.include(source)
	plan.revisions[0] = revision
	var stack := copy._by_uid(uid)
	if stack == null:
		plan.error = ERR_INVALID_DATA
		return plan
	var definition := ItemCatalog.resolve(stack.item_id)
	if not definition.spoilage.is_empty() and StackPolicy.remaining(stack.instance_data,definition,copy.time_source.now) <= 0:
		plan.error = ERR_UNAVAILABLE
		return plan
	var context := context_for(actor,copy)
	copy.consume_uid(uid,1)
	for graph: String in graphs:
		plan.error = EffectGraph.prepare(graph,"OnConsume",context)
		if plan.error != OK: return plan
	plan.publications.append(publication(actor,context))
	return plan
static func hit(actor: PlayerActor, target: Node3D, payload: HitPayload, graphs: Array) -> float:
	if graphs.is_empty(): return float(target.receive_hit(payload))
	var plan := InventoryPlan.new()
	var needs_inventory := graphs.any(func(id: String) -> bool: return EffectGraph.compile(id).get("inventory",false))
	var context := context_for(actor,plan.include(actor.inventory.state) if needs_inventory else null,str(payload.attack_instance)+":"+str(target.get_instance_id()))
	context.damage_input = payload.raw_damage
	context.tags = Array(target.get_groups())
	for graph: String in graphs:
		if EffectGraph.prepare(graph,"OnHit",context) != OK: return 0
	var result := {"amount":0.0}
	var effect := publication(actor,context)
	var previous_apply := effect.apply
	effect.apply = func() -> void:
		previous_apply.call()
		payload.raw_damage = context.damage
		result.amount = float(target.receive_hit(payload)) if context.damage > 0 else 0.0
	var previous_validate := effect.validate
	effect.validate = func() -> bool: return previous_validate.call() and is_instance_valid(target) and target.has_method("receive_hit")
	plan.publications.append(effect)
	return float(result.amount) if plan.commit() == OK else 0.0
