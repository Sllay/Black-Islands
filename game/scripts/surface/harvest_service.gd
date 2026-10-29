class_name HarvestService
extends RefCounted
## Same extraction algorithm for props and corpses. Candidate state is committed
## with output by the caller; expected revision/strike prevent duplicate callbacks.
static func create(definition: String) -> Dictionary:
	var data: Dictionary = SurfaceCatalog.data().harvestables[definition]
	return {"definition":definition,"base_health":data.health,"health":data.health,
		"reserves":data.reserves.duplicate(),"carry":{},"revision":0,"last_strike":""}

static func strike(state: Dictionary, profile: Dictionary, revision: int, command: String) -> Dictionary:
	if state.revision != revision or state.last_strike == command or command.is_empty() or state.health <= 0:
		return {"error":ERR_ALREADY_IN_USE}
	var next := state.duplicate(true)
	var definition: Dictionary = SurfaceCatalog.data().harvestables[state.definition]
	var affinity := float(profile.get("targets",{}).get(definition.tag,0.15))
	var requested := float(profile.power)*float(profile.get("quality_power",1.0))*affinity
	var actual := minf(maxf(0,requested),float(state.health))
	var outputs: Dictionary = {}
	for id: String in state.reserves:
		var fraction := actual/float(state.base_health)
		var budget := fraction*float(definition.reserves[id])*float(profile.efficiency)*float(profile.get("quality_yield",1.0))*float(profile.resources.get(id,0.25))
		var carry := budget+float(next.carry.get(id,0))
		var amount := mini(int(next.reserves[id]),int(floor(carry)))
		next.carry[id] = carry-floor(carry)
		next.reserves[id] -= amount
		if amount > 0:
			outputs[id] = amount
	next.health = maxf(0,float(next.health)-actual)
	next.revision += 1
	next.last_strike = command
	return {"error":OK,"state":next,"outputs":outputs,"actual_damage":actual,"requested_damage":requested}
