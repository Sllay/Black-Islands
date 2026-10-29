class_name FarmSystem
extends RefCounted
## Dedicated world-cell crop state, evaluated by the session scheduler.
var plots: Dictionary = {}
var ledger: SurfaceLedger
var crop: Dictionary

func _init(world_ledger: SurfaceLedger) -> void:
	ledger = world_ledger
	crop = SurfaceCatalog.data().crop

func till(point: Vector3, supported: bool, material: int) -> Error:
	var key := SurfaceLedger.cell_key(point)
	if not supported or material not in [1,2] or plots.has(key):
		return ERR_INVALID_DATA
	plots[key] = {"id":"farm:"+key,"cell":key,"position":[point.x,point.y,point.z],"soil_state":"TILLED_DRY",
		"seed_id":"","crop_id":"","moisture":0.0,"moisture_deadline":0.0,"growth_progress":0.0,
		"growth_stage":0,"fertilizer_id":"","fertilizer_multiplier":1.0,"dry_elapsed":0.0,
		"dry_decay_deadline":ledger.active_seconds+1800,"unsupported":false,
		"last_clock":ledger.clock,"last_active":ledger.active_seconds,"revision":0}
	ledger.suppress(point,"farm:"+key)
	return OK

func plant(key: String, inventory: InventoryState) -> Error:
	if not plots.has(key) or not plots[key].seed_id.is_empty():
		return ERR_INVALID_DATA
	if InventoryTransactions.pay(inventory,{crop.seed_item_id:1}) != OK:
		return ERR_UNAVAILABLE
	var plot: Dictionary = plots[key]
	plot.seed_id = crop.seed_item_id
	plot.crop_id = crop.crop_id
	plot.growth_progress = 0.0
	plot.revision += 1
	return OK

func water(key: String, days: float = 1.0) -> Error:
	if not plots.has(key):
		return ERR_DOES_NOT_EXIST
	evaluate()
	var plot: Dictionary = plots[key]
	plot.moisture_deadline = maxf(float(plot.moisture_deadline),ledger.clock+clampf(days,1,3)*SurfaceLedger.DAY)
	plot.dry_elapsed = 0
	plot.dry_decay_deadline = ledger.active_seconds+1800
	plot.soil_state = "TILLED_WET" if plot.seed_id.is_empty() else "GROWING"
	plot.revision += 1
	return OK

func rain(area: AABB, heavy: bool) -> void:
	for key: String in plots.keys():
		var point: Array = plots[key].position
		if area.has_point(Vector3(point[0],point[1],point[2])):
			water(key,3 if heavy else 1)

func evaluate() -> Array[String]:
	var removed: Array[String] = []
	for key: String in plots.keys():
		var plot: Dictionary = plots[key]
		var wet_seconds := maxf(0,minf(ledger.clock,float(plot.moisture_deadline))-float(plot.last_clock))
		if not plot.seed_id.is_empty():
			plot.growth_progress = minf(1.0,float(plot.growth_progress)+wet_seconds*float(plot.fertilizer_multiplier)/(float(crop.growth_days)*SurfaceLedger.DAY))
			plot.growth_stage = mini(int(crop.growth_stages)-1,int(float(plot.growth_progress)*float(crop.growth_stages)))
		if ledger.clock >= float(plot.moisture_deadline):
			plot.dry_elapsed += maxf(0,ledger.active_seconds-float(plot.last_active))
			plot.moisture = 0
		else:
			plot.moisture = clampf((float(plot.moisture_deadline)-ledger.clock)/SurfaceLedger.DAY,0,3)
		plot.last_clock = ledger.clock
		plot.last_active = ledger.active_seconds
		if float(plot.growth_progress) >= 1:
			plot.soil_state = "HARVEST_READY"
		if float(plot.dry_elapsed) >= 1800:
			removed.append(key)
	return removed

func harvest(key: String) -> Dictionary:
	evaluate()
	if not plots.has(key) or float(plots[key].growth_progress) < 1:
		return {}
	var plot: Dictionary = plots[key]
	plot.seed_id = ""
	plot.crop_id = ""
	plot.growth_progress = 0.0
	plot.growth_stage = 0
	plot.revision += 1
	return {crop.harvest_item:int(crop.harvest_amount),crop.seed_item_id:int(crop.seed_return)}

func remove(key: String, unsupported: bool = false) -> Dictionary:
	if not plots.has(key):
		return {}
	var plot: Dictionary = plots[key]
	var point := Vector3(plot.position[0],plot.position[1],plot.position[2])
	var outputs: Dictionary = {}
	if not plot.seed_id.is_empty() and crop.return_seed_on_break:
		outputs[crop.seed_item_id] = 1
	plot.unsupported = unsupported
	plots.erase(key)
	ledger.release(point,"farm:"+key)
	return outputs
