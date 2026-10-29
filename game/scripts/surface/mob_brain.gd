class_name MobBrain
extends RefCounted
## Replaceable condition executor. No species-specific controller branches.
static func choose(definition: Dictionary, context: Dictionary) -> String:
	for rule: Dictionary in definition.rules:
		var matches := true
		for condition: String in rule.all:
			if not _matches(context.get(condition),rule.all[condition]):
				matches = false
				break
		if matches:
			return rule.intent
	return "WANDER"

static func _matches(actual: Variant, requirement: Variant) -> bool:
	if requirement is Dictionary:
		if not (actual is int or actual is float):
			return false
		return actual >= float(requirement.get("gte",-INF)) and actual <= float(requirement.get("lte",INF))
	return actual == requirement

static func tier(distance: float) -> String:
	if distance < 24:
		return "ACTIVE"
	if distance < 48:
		return "NEAR_PROXY"
	return "REGIONAL" if distance < 128 else "STASIS"
