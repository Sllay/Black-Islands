class_name SurfaceActions
extends RefCounted
## Production intents compose domain operations; UI never edits inventories/state.
var runtime: SurfaceRuntime
var selected_structure := "foundation"
var tier := "wood"
var rotation := 0
var selected_support := ""

func _init(surface: SurfaceRuntime) -> void:
	runtime = surface

func primary() -> void:
	var item := runtime.player.inventory.state.active_definition()
	if item == null:
		return
	var target := runtime.player.targeter.current
	if item.category == "BUILDING_PIECE":
		build_at(snap_cell(target),selected_support)
		return
	if item.id in SurfaceCatalog.data().tools:
		if target.entity is PropActor:
			runtime.harvest_prop(target.entity.spawn_id,runtime.player)
		elif is_instance_valid(target.entity) and target.entity.has_method("harvest"):
			target.entity.harvest()
		return
	var point := target.world_position
	var key := SurfaceLedger.cell_key(point)
	if target.entity is SurfaceObject and target.entity.role == "farm":
		key = target.entity.object_id
	if item.id == "bi.tool.watering_can":
		runtime.farms.water(key)
	elif item.id == "bi.tool.hoe":
		if runtime.farms.plots.has(key):
			farm_interact(key)
		else:
			if target.kind not in [TargetResult.Kind.TERRAIN,TargetResult.Kind.BUILD_GRID] or target.normal.y < .8:
				runtime.message.emit("Escolha solo plano e livre.")
				return
			var cell := WorldCoordinates.world_to_cell(point)
			if runtime.building.occupancy.has(SupportGraph.slot("foundation",cell)) or runtime.ledger.suppressed(point):
				runtime.message.emit("Este solo está ocupado.")
				return
			var material := runtime.terrain.material_at(point)
			if material not in [1,2] or runtime.session.edits.apply(point,.55,true,2) != OK:
				runtime.message.emit("O solo ainda não pode ser preparado.")
				return
			var anchor := Vector3(cell.x+.5,point.y+.02,cell.z+.5)
			runtime.farms.till(anchor,true,material)
			runtime.refresh(anchor)
	elif item.id == "bi.tool.shovel":
		if target.kind in [TargetResult.Kind.TERRAIN,TargetResult.Kind.BUILD_GRID]:
			var path_exists: bool = "path" in runtime.ledger.suppression.get(key,{}).get("reasons",[])
			if runtime.session.edits.apply(point,.7,true,1 if path_exists else 2) == OK:
				if path_exists:
					runtime.ledger.release(point,"path")
				else:
					runtime.ledger.suppress(point,"path")
				runtime.refresh(point)
	runtime.objects.reconcile()

func snap_cell(target: TargetResult) -> Vector3i:
	selected_support = ""
	if not target.entity is SurfaceObject or target.entity.role != "structure":
		var point := StructureModule.snap(target.build_cell)
		if selected_structure in ["foundation","pillar","chest"]:
			point.y = roundi(target.world_position.y)
		return point
	var source: Dictionary = runtime.building.pieces.get(target.entity.object_id,{})
	if source.is_empty():
		return StructureModule.snap(target.build_cell)
	var base := SupportGraph.cell(source)
	if selected_structure == "chest" and source.definition in ["foundation","ceiling"]:
		selected_support = str(source.id)
		return base
	var relative := target.world_position-StructureModule.center(base)
	var direction := Vector3i.RIGHT if relative.x >= 0 else Vector3i.LEFT
	if absf(relative.z) > absf(relative.x):
		direction = Vector3i.BACK if relative.z >= 0 else Vector3i.FORWARD
	if selected_structure == "wall":
		if source.definition == "wall":
			rotation = int(source.rotation)
			return base+Vector3i.UP*StructureModule.HEIGHT
		rotation = [Vector3i.RIGHT,Vector3i.BACK,Vector3i.LEFT,Vector3i.FORWARD].find(direction)
		return base
	if source.definition in ["pillar","wall"]:
		return base+Vector3i.UP*StructureModule.HEIGHT
	return base if selected_structure == "pillar" else base+direction*StructureModule.SIZE

func farm_interact(key: String) -> void:
	if not runtime.farms.plots.has(key):
		return
	var plot: Dictionary = runtime.farms.plots[key]
	if plot.seed_id.is_empty():
		var error := runtime.farms.plant(key,runtime.player.inventory.state)
		runtime.message.emit("Semente plantada. Use o regador." if error == OK else "Você precisa de sementes de nabo.")
	elif plot.growth_progress >= 1:
		runtime.deliver(runtime.farms.harvest(key),Vector3(plot.position[0],plot.position[1],plot.position[2]))
		runtime.message.emit("Colheita recolhida.")
	else:
		runtime.message.emit("Nabo • crescimento %d%% • água %s" % [plot.growth_progress*100,"disponível" if plot.moisture_deadline > runtime.ledger.clock else "necessária"])
	runtime.objects.reconcile()

func build_at(cell: Vector3i, support_id: String = "") -> Error:
	cell = StructureModule.snap(cell)
	if selected_structure == "chest":
		var point := StructureModule.center(cell)+Vector3.UP*.02
		var supported := runtime.ground_contact(cell)
		if support_id.is_empty():
			var hit := runtime.terrain.surface_hit(point.x,point.z)
			if not hit.is_empty():
				point.y = hit.position.y+.02
			else:
				supported = false
		if not support_id.is_empty():
			var floor_row: Dictionary = runtime.building.pieces.get(support_id,{})
			supported = not floor_row.is_empty() and floor_row.definition in ["foundation","ceiling"] and not runtime.building.candidates.get(support_id,{}).is_empty()
			point.y += float(SurfaceCatalog.data().structures.foundation.dimensions[1])
		if not supported or not runtime.containers.in_area(AABB(point-Vector3.ONE*.3,Vector3.ONE*.6)).is_empty():
			return ERR_UNAVAILABLE
		if InventoryTransactions.pay(runtime.player.inventory.state,{"bi.resource.wood":8}) != OK:
			return ERR_UNAVAILABLE
		var chest_id := runtime.ledger.new_id("chest")
		runtime.containers.create(chest_id,point)
		runtime.containers.records[chest_id].support_id = support_id
		runtime.objects.reconcile()
		return OK
	var id := runtime.ledger.new_id("structure")
	var error := runtime.building.place(id,selected_structure,cell,rotation,tier)
	if error != OK:
		runtime.message.emit("Sem suporte válido ou espaço livre.")
		return error
	var costs: Dictionary = SurfaceCatalog.data().structures[selected_structure].cost.duplicate()
	for item: String in costs:
		costs[item] = ceili(float(costs[item])*float(SurfaceCatalog.data().tiers[tier].cost_multiplier))
	error = InventoryTransactions.pay(runtime.player.inventory.state,costs)
	if error != OK:
		runtime.building.remove(id)
		runtime.message.emit("Faltam madeira/pedra.")
		return error
	if selected_structure == "foundation":
		runtime.foundation_foliage(runtime.building.pieces[id],true)
	runtime.objects.reconcile()
	return OK

func demolish(id: String) -> void:
	for row: Dictionary in runtime.building.remove(id):
		if row.definition == "foundation":
			runtime.foundation_foliage(row,false)
		runtime.reconcile_container_support(AABB(Vector3(SupportGraph.cell(row)),Vector3(2,4,2)))
	runtime.objects.reconcile()
