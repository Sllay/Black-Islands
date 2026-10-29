class_name LPCCustomization
extends RefCounted
## UI options are catalog queries, not a hand-maintained list of sprite paths.
static func roles() -> Array[String]:
	var result: Array[String] = []
	for entry: Dictionary in LPCCatalog.data().assets:
		if entry.role != "weapon" and entry.role not in result:
			result.append(entry.role)
	return result

static func body_types() -> Array[String]:
	var result: Array[String] = []
	for entry: Dictionary in LPCCatalog.data().assets:
		if entry.role == "body":
			for body: String in entry.body_types:
				if body in ["male","female"] and body not in result:
					result.append(body)
	return result

static func immutable_roles() -> Array[String]:
	return ["body","head","ears","nose","eyes","hair"]

static func options(role: String, body: String, skin: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for entry: Dictionary in LPCCatalog.data().assets:
		if entry.role != role or body not in entry.body_types or entry.legal_status != "accepted":
			continue
		if entry.get("match_body_color",false) and not skin.is_empty() and entry.palette != skin:
			continue
		result.append(entry)
	return result

static func default_for(body: String) -> Dictionary:
	var config := LPCCatalog.default_appearance()
	config.body_type = body
	config.selections.clear()
	config.palettes.clear()
	for role: String in roles():
		var rows := options(role,body,str(config.palettes.get("body","")))
		if rows.is_empty():
			continue
		config.selections[role] = rows[0].id
		config.palettes[role] = rows[0].palette
	return config

static func select(config: Dictionary, role: String, id: String) -> Dictionary:
	var result := config.duplicate(true)
	var entry := LPCCatalog.asset(id)
	if entry.is_empty():
		return result
	result.selections[role] = id
	result.palettes[role] = entry.palette
	if role == "body":
		for other: String in roles():
			var current := LPCCatalog.asset(str(result.selections.get(other,"")))
			if current.get("match_body_color",false):
				var rows := options(other,str(result.body_type),str(entry.palette))
				if not rows.is_empty():
					result.selections[other] = rows[0].id
					result.palettes[other] = rows[0].palette
	return result
