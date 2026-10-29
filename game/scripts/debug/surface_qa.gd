class_name SurfaceQA
extends Node
## Explicit debug acceleration on the actual session/services, not a second game.
var runtime: SurfaceRuntime
var result: Dictionary = {}

func c02() -> void:
	result = {"running":true}
	var point := runtime.player.global_position+Vector3(3,0,3)
	var hit := runtime.terrain.surface_hit(point.x,point.z)
	if hit.is_empty():
		result = {"error":"no terrain"}
		return
	point = Vector3(floorf(point.x)+.5,hit.position.y+.02,floorf(point.z)+.5)
	var before := runtime.terrain.density_at(point)
	var error := runtime.session.edits.apply(point,.55,true,2)
	if error != OK:
		result = {"error":"terrain busy", "code":error}
		return
	var key := SurfaceLedger.cell_key(point)
	if not runtime.farms.plots.has(key):
		error = runtime.farms.till(point,true,1)
		runtime.farms.plant(key,runtime.player.inventory.state)
	runtime.farms.water(key,3)
	runtime.qa_advance(2)
	var outputs := runtime.farms.harvest(key)
	runtime.deliver(outputs,point)
	runtime.farms.plant(key,runtime.player.inventory.state)
	runtime.farms.water(key,3)
	runtime.qa_advance(1)
	var base := Vector3i(floori(point.x)+2,floori(point.y),floori(point.z))
	var ids: Array[String] = []
	var errors: Array = []
	for entry: Array in [["foundation",Vector3i.ZERO],["wall",Vector3i.ZERO],["ceiling",Vector3i(0,2,0)],["ceiling",Vector3i(1,0,0)],["pillar",Vector3i(1,0,0)]]:
		runtime.actions.selected_structure = entry[0]
		var prior: Array = runtime.building.pieces.keys()
		var placed := runtime.actions.build_at(base+Vector3i(entry[1]))
		errors.append(placed)
		for id: String in runtime.building.pieces:
			if id not in prior:
				ids.append(id)
	runtime.actions.selected_structure = "chest"
	errors.append(runtime.actions.build_at(base+Vector3i(0,0,2)))
	runtime.refresh(point)
	runtime.objects.reconcile()
	result = {"running":false,"plot":key,"crop_output":outputs,"density_unchanged":before == runtime.terrain.density_at(point),"placement_errors":errors,"structure_ids":ids,"containers":runtime.containers.records.size()}
	print("P04_QA_C02 ",result)

func open_chest() -> void:
	for id: String in runtime.containers.records:
		if runtime.containers.records[id].kind == "Chest":
			runtime.container_opened.emit(id)
			return

func break_plot() -> void:
	if runtime.farms.plots.is_empty():
		return
	var key: String = runtime.farms.plots.keys()[0]
	var row: Dictionary = runtime.farms.plots[key]
	var point := Vector3(row.position[0],row.position[1],row.position[2])
	var error := runtime.session.edits.apply(point,1.3,false)
	await get_tree().create_timer(1.5).timeout
	result = {"edit_error":error,"unsupported_plot_removed":not runtime.farms.plots.has(key),"key":key}
	print("P04_QA_SUPPORT_BREAK ",result)
