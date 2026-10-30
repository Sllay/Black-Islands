class_name SurfaceSaveValidator
extends RefCounted
## Validate new surface payload before touching a live scene or accepting writes.
static func validate(data: Dictionary, player_inventory: Dictionary) -> Error:
	if data.get("schema_version") != 1:
		return ERR_UNAVAILABLE
	if data.get("content_version",1) != SurfaceCatalog.VERSION:
		return ERR_UNAVAILABLE
	for key: String in ["props","suppression","bags"]:
		if not data.get(key) is Dictionary:
			return ERR_INVALID_DATA
	for key: String in ["farms","structures","containers","mobs","flags"]:
		if not data.get(key,{}) is Dictionary:
			return ERR_INVALID_DATA
	for key: String in ["clock","active_seconds"]:
		if not number(data.get(key),0,1e12):
			return ERR_INVALID_DATA
	var catalog := SurfaceCatalog.data()
	for state: Variant in data.props.values():
		if not state is Dictionary or not valid_harvest(state):
			return ERR_INVALID_DATA
	for plot: Variant in data.get("farms",{}).values():
		if not plot is Dictionary or not vector(plot.get("position")) or not number(plot.get("growth_progress"),0,1) or not number(plot.get("moisture_deadline"),0,1e12):
			return ERR_INVALID_DATA
		if plot.get("seed_id","") not in ["",catalog.crop.seed_item_id] or plot.get("crop_id","") not in ["",catalog.crop.crop_id]:
			return ERR_UNAVAILABLE
	var slots: Dictionary = {}
	for id: Variant in data.get("structures",{}):
		var row: Variant = data.structures[id]
		if not id is String or not row is Dictionary or row.get("id") != id or not vector(row.get("cell")) or row.get("definition") not in catalog.structures or row.get("tier") not in catalog.tiers:
			return ERR_INVALID_DATA
		for coordinate: Variant in row.cell:
			if coordinate != int(coordinate):
				return ERR_INVALID_DATA
		if row.cell[1]+2 > 100 or not number(row.get("health"),0,100000) or not number(row.get("rotation"),0,3) or row.rotation != int(row.rotation):
			return ERR_INVALID_DATA
		var key := SupportGraph.slot(row.definition,SupportGraph.cell(row),int(row.rotation))
		if key != row.get("occupancy") or slots.has(key):
			return ERR_INVALID_DATA
		slots[key] = true
	var owned: Dictionary = {}
	if not inventory(player_inventory,owned):
		return ERR_INVALID_DATA
	var containers: Dictionary = data.get("containers",{}).duplicate()
	for id: String in data.bags:
		if containers.has(id):
			return ERR_INVALID_DATA
		containers[id] = data.bags[id]
	for id: Variant in containers:
		var row: Variant = containers[id]
		if not id is String or not row is Dictionary or row.get("id") != id or not vector(row.get("position")) or not row.get("inventory") is Dictionary or not inventory(row.inventory,owned):
			return ERR_INVALID_DATA
	for id: Variant in data.get("mobs",{}):
		var row: Variant = data.mobs[id]
		if not id is String or not row is Dictionary or row.get("id") != id or row.get("definition") not in catalog.mobs or not vector(row.get("position")) or not number(row.get("health"),0,100000):
			return ERR_INVALID_DATA
		if row.get("life") not in ["ALIVE","DEATH","CORPSE","REMOVED"]:
			return ERR_INVALID_DATA
		if row.life == "CORPSE" and (not containers.has(row.get("corpse_inventory")) or not valid_harvest(row.get("harvest",{}))):
			return ERR_INVALID_DATA
	return OK

static func valid_harvest(state: Dictionary) -> bool:
	if state.get("definition") not in SurfaceCatalog.data().harvestables or not number(state.get("base_health"),.001,100000) or not number(state.get("health"),0,float(state.base_health)) or not state.get("reserves") is Dictionary:
		return false
	var source: Dictionary = SurfaceCatalog.data().harvestables[state.definition]
	if state.base_health != source.health or not number(state.get("revision"),0,1e12) or not state.get("last_strike") is String or not state.get("carry") is Dictionary:
		return false
	for id: Variant in state.carry:
		if id not in source.reserves or not number(state.carry[id],0,1):
			return false
	for id: Variant in state.reserves:
		var definition: Dictionary = SurfaceCatalog.data().harvestables[state.definition]
		if not id is String or not definition.reserves.has(id) or ItemCatalog.resolve(id) == null or not number(state.reserves[id],0,float(definition.reserves.get(id,0))) or state.reserves[id] != int(state.reserves[id]):
			return false
	return true

static func inventory(record: Dictionary, owned: Dictionary) -> bool:
	if InventoryState.new().restore(record) != OK:
		return false
	var rows: Array = record.slots.duplicate()
	rows.append_array(record.get("pending_outputs",[]))
	for row: Variant in rows:
		if row == null:
			continue
		if owned.has(row.stack_uid):
			return false
		owned[row.stack_uid] = true
	return true

static func vector(value: Variant) -> bool:
	return value is Array and value.size() == 3 and number(value[0],-100000,100000) and number(value[1],-100000,100000) and number(value[2],-100000,100000)

static func number(value: Variant, low: float, high: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and value >= low and value <= high
