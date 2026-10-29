class_name SurfaceRuntime
extends Node3D
## Session composition boundary. Modules own state/rules; views own no truth.
signal message(text: String)
var player: PlayerActor
var terrain: VoxelTerrainAdapter
var field: PropField
var ledger := SurfaceLedger.new()
var foliage: FoliagePresenter
var candidates: Dictionary = {}
var edited_patches: Dictionary = {}
var _definitions: Dictionary = {}
var _elapsed := 0.0

signal container_opened(id: String)
var session: WorldSession
var farms: FarmSystem
var building: SupportGraph
var containers: ContainerService
var objects: SurfaceObjects
var actions: SurfaceActions

func ground_contact(cell: Vector3i) -> bool:
	return _ground_at(StructureModule.center(cell))

func _ground_at(point: Vector3) -> bool:
	return _density(point-Vector3.UP*.55) < 0 and _density(point+Vector3.UP*.55) > 0

func foundation_contact(cell: Vector3i) -> bool:
	return StructureModule.footprint_supported(cell,_ground_at)

func _density(point: Vector3) -> float:
	var voxel := WorldCoordinates.world_to_voxel(point)
	var edits := session.store.snapshot_box(voxel,Vector3i.ONE)
	return DensityCodec.metres(edits[voxel].density) if edits.has(voxel) else terrain.field.density(point)

func deliver(outputs: Dictionary, point: Vector3) -> void:
	if outputs.is_empty():
		return
	var result := InventoryTransactions.output(player.inventory.state,outputs)
	if result.error == OK and not result.overflow.is_empty():
		create_bag(point,result.overflow)

func interact_object(id: String, role: String) -> void:
	if role == "container":
		container_opened.emit(id)
	elif role == "farm":
		actions.farm_interact(id)
	elif role == "structure":
		actions.demolish(id)

func qa_advance(days: float) -> void:
	ledger.clock += maxf(days,0)*SurfaceLedger.DAY
	_tick_domains()

func _tick_domains() -> void:
	for key: String in farms.evaluate():
		var row: Dictionary = farms.plots[key]
		var point := Vector3(row.position[0],row.position[1],row.position[2])
		create_bag(point,farms.remove(key))
		refresh(point)
	objects.reconcile()

var qa: SurfaceQA

func _attach_qa() -> void:
	if not OS.is_debug_build() or session.tools == null:
		return
	var entries := [["P04 • cultivo / construção",qa.c02],["P04 • fauna",qa.c03],["P04 • combate / corpo",qa.combat_sample],["P04 • offscreen",qa.offscreen_sample],
		["+1 dia (QA)",func() -> void: qa_advance(1)],["+6 dias / regrowth (QA)",func() -> void: qa_advance(6)]]
	for entry: Array in entries:
		var button := ShellUI.button(entry[0],"SurfaceQA",Vector2(330,44))
		button.pressed.connect(entry[1])
		session.tools.add_child(button)

var mobs: MobSimulation

func _configure_mobs(restored: Dictionary) -> void:
	mobs = MobSimulation.new()
	mobs.name = "Mobs"
	add_child(mobs)
	mobs.configure(self,restored.get("mobs",{}))

func configure(world_session: WorldSession, restored: Dictionary = {}) -> void:
	session = world_session
	player = session.pawn
	terrain = session.terrain
	field = PropField.new(terrain.field)
	for voxel: Vector3i in session.store.snapshot_box(Vector3i(-960,-256,-960),Vector3i(1920,768,1920)):
		var point := Vector3(voxel)*WorldCoordinates.VOXEL_SIZE
		edited_patches[Vector2i(floori(point.x/16),floori(point.z/16))] = true
	for row: Dictionary in SurfaceCatalog.data().props:
		_definitions[row.id] = row
	if not restored.is_empty():
		assert(ledger.restore(restored) == OK)
	farms = FarmSystem.new(ledger)
	farms.plots = restored.get("farms",{}).duplicate(true)
	building = SupportGraph.new()
	building.ground = ground_contact
	building.foundation_ground = foundation_contact
	assert(building.restore(restored.get("structures",{})) == OK)
	containers = ContainerService.new()
	assert(containers.restore(restored.get("containers",{})) == OK)
	# Migrate C01 bag records once; do not retain a second inventory owner.
	for id: String in ledger.bags:
		var row: Dictionary = ledger.bags[id].duplicate(true)
		row.kind = row.get("policy","WorldDropBag")
		assert(containers.restore({id:row}) == OK)
	ledger.bags.clear()
	actions = SurfaceActions.new(self)
	add_to_group("surface_runtime")
	foliage = FoliagePresenter.new()
	foliage.runtime = self
	add_child(foliage)
	objects = SurfaceObjects.new()
	objects.runtime = self
	add_child(objects)
	for row: Dictionary in building.removed_on_restore:
		if row.definition == "foundation":
			foundation_foliage(row,false)
	for row: Dictionary in containers.records.values().duplicate():
		if row.kind == "Chest":
			var point := Vector3(row.position[0],row.position[1],row.position[2])
			reconcile_container_support(AABB(point-Vector3.ONE,Vector3.ONE*2))
	_configure_mobs(restored)
	var ui: SurfaceUI = load("res://scenes/ui/SurfaceGameplayUI.tscn").instantiate()
	ui.runtime = self
	add_child(ui)
	qa = SurfaceQA.new()
	qa.name = "QA"
	qa.runtime = self
	add_child(qa)
	_attach_qa.call_deferred()
	session.edits.terrain_changed.connect(terrain_changed)
	_provision_tools()

func _provision_tools() -> void:
	if ledger.flags.get("starter_tools",false):
		return
	var kit := {"bi.tool.axe":1,"bi.tool.knife":1,"bi.tool.hoe":1,"bi.tool.watering_can":1,"bi.tool.shovel":1,"bi.seed.turnip":8}
	var output := InventoryTransactions.output(player.inventory.state,kit)
	if output.error != OK:
		return
	if not output.overflow.is_empty():
		var point := player.position
		point.y = terrain.field.top_surface(point.x,point.z)
		create_bag(point,output.overflow)
	var quickbar_tools := ["bi.tool.axe","bi.tool.knife","bi.tool.hoe","bi.tool.watering_can"]
	for slot: int in range(InventoryState.CAPACITY):
		var row := player.inventory.state.slot_at(slot)
		if row.get("item_id","") in quickbar_tools:
			player.inventory.state.assign_hotbar(4+quickbar_tools.find(row.item_id),slot)
	ledger.flags.starter_tools = true

func definition(id: String) -> Dictionary:
	return _definitions[id]

func destroyed(id: String) -> bool:
	return ledger.props.has(id) and float(ledger.props[id].health) <= 0

func _regrow() -> void:
	for key: String in ledger.suppression.keys():
		var row: Dictionary = ledger.suppression[key]
		if not row.reasons.is_empty() or ledger.clock < float(row.regrow_at):
			continue
		var parts := key.split(",")
		var point := Vector3(float(parts[0])+.5,float(parts[1])+.04,float(parts[2])+.5)
		var hit := terrain.surface_hit(point.x,point.z)
		if hit.is_empty() or absf(float(hit.position.y)-point.y) > .6:
			continue
		if terrain.material_at(hit.position) == 2 and session.edits.apply(hit.position,.55,true,1) != OK:
			continue
		ledger.suppression.erase(key)
		refresh(point)

func _process(delta: float) -> void:
	if player == null or not player.spawned or player.inventory.is_open:
		return
	ledger.clock += delta
	ledger.active_seconds += delta
	_elapsed += delta
	if _elapsed >= 1:
		_elapsed = 0
		_tick_domains()
		_regrow()

func primary_action() -> void:
	actions.primary()

func qa_resource(kind: String, tool_id: String) -> Dictionary:
	# QA relocation uses the same range/revision/output path as production.
	var chosen := ""
	var nearest := INF
	for id: String in candidates:
		var candidate: Dictionary = candidates[id]
		if definition(candidate.definition).harvest != kind or destroyed(id):
			continue
		var candidate_point := Vector3(candidate.point[0],candidate.point[1],candidate.point[2])
		var distance := candidate_point.distance_squared_to(player.global_position)
		if distance < nearest:
			nearest = distance
			chosen = id
	if chosen.is_empty():
		return {"error":ERR_DOES_NOT_EXIST}
	var row: Dictionary = candidates[chosen]
	var point := Vector3(row.point[0],row.point[1],row.point[2])
	player.motor.request_spawn(point+Vector3(0,2,2))
	for slot: int in InventoryState.CAPACITY:
		if player.inventory.state.slot_at(slot).get("item_id") == tool_id:
			player.inventory.state.assign_hotbar(4,slot)
			player.inventory.state.select_hotbar(4)
	return {"id":chosen,"result":harvest_prop(chosen,player)}

func harvest_prop(id: String, actor: PlayerActor) -> Dictionary:
	var item := actor.inventory.state.active_definition()
	if item == null or not SurfaceCatalog.data().tools.has(item.id) or not candidates.has(id):
		message.emit("Escolha machado, picareta ou faca na hotbar.")
		return {"error":ERR_INVALID_PARAMETER}
	var row: Dictionary = candidates[id]
	var location := Vector3(row.point[0],row.point[1],row.point[2])
	if actor.global_position.distance_to(location) > 4:
		return {"error":ERR_UNAUTHORIZED}
	var tool: Dictionary = SurfaceCatalog.data().tools[item.id]
	if not actor.state.consume(float(tool.stamina)):
		return {"error":ERR_UNAVAILABLE}
	var state: Dictionary = ledger.props.get(id,HarvestService.create(definition(row.definition).harvest))
	var result := HarvestService.strike(state,tool,int(state.revision),ledger.new_id("strike"))
	if result.error != OK:
		return result
	var output := InventoryTransactions.output(actor.inventory.state,result.outputs)
	if output.error != OK:
		return output
	ledger.props[id] = result.state
	if not output.overflow.is_empty():
		create_bag(location,output.overflow)
	actor.visual.play_semantic(LPCActionResolver.MELEE_SLASH,.4)
	var labels: PackedStringArray = []
	for item_id: String in result.outputs:
		labels.append("%s ×%d" % [ItemCatalog.resolve(item_id).title,result.outputs[item_id]])
	message.emit("Coletado: "+", ".join(labels))
	refresh(location)
	return result

func create_bag(point: Vector3, contents: Dictionary) -> String:
	if contents.is_empty():
		return ""
	var id := ledger.new_id("drop")
	var inventory := containers.create(id,point,"WorldDropBag")
	InventoryTransactions.output(inventory,contents)
	objects.reconcile()
	return id

func refresh(point: Vector3) -> void:
	foliage.invalidate(AABB(point-Vector3(1,2,1),Vector3(3,4,3)))

func terrain_changed(area: AABB) -> void:
	for key: Vector2i in foliage.patches:
		if AABB(Vector3(key.x*16,-128,key.y*16),Vector3(16,384,16)).intersects(area):
			edited_patches[key] = true
	await get_tree().create_timer(.5).timeout
	foliage.invalidate(area)
	for key: String in farms.plots.keys():
		var row: Dictionary = farms.plots[key]
		var point := Vector3(row.position[0],row.position[1],row.position[2])
		if not area.grow(1).has_point(point):
			continue
		# A streamed-out collider is not missing support. Read persisted SDF.
		if _density(point-Vector3.UP*.3) > 0 or _density(point+Vector3.UP*.5) < 0:
			create_bag(point,farms.remove(key,true))
			refresh(point)
	for row: Dictionary in building.terrain_changed(area):
		if row.definition == "foundation":
			foundation_foliage(row,false)
		reconcile_container_support(AABB(Vector3(SupportGraph.cell(row)),Vector3(2,4,2)))
	reconcile_container_support(area)
	objects.reconcile()

func foundation_foliage(row: Dictionary, suppress: bool) -> void:
	var cell := SupportGraph.cell(row)
	for z: int in StructureModule.SIZE:
		for x: int in StructureModule.SIZE:
			var point := Vector3(cell)+Vector3(x+.5,.05,z+.5)
			if suppress:
				ledger.suppress(point,"foundation:"+str(row.id))
			else:
				ledger.release(point,"foundation:"+str(row.id))
			refresh(point)

func reconcile_container_support(area: AABB) -> void:
	for id: String in containers.in_area(area.grow(1)):
		var row: Dictionary = containers.records[id]
		if row.kind != "Chest":
			continue
		var support: String = row.get("support_id","")
		var valid := false
		if not support.is_empty():
			valid = building.pieces.has(support) and not building.candidates.get(support,{}).is_empty()
		else:
			var point := Vector3(row.position[0],row.position[1],row.position[2])
			valid = _density(point-Vector3.UP*.14) < 0 and _density(point+Vector3.UP*.18) > 0
		if not valid:
			containers.break_chest(id)
	objects.reconcile()

func snapshot() -> Dictionary:
	mobs.sync_positions()
	var data := ledger.snapshot()
	data.content_version = SurfaceCatalog.VERSION
	data.structure_module_version = 2
	data.farms = farms.plots.duplicate(true)
	data.structures = building.pieces.duplicate(true)
	data.containers = containers.snapshot()
	data.mobs = mobs.domain.states.duplicate(true)
	return data

func report() -> Dictionary:
	var exhausted := 0
	var bags := 0
	var batches := 0
	for id: String in ledger.props:
		if destroyed(id):
			exhausted += 1
	for row: Dictionary in containers.records.values():
		bags += int(row.kind in ["WorldDropBag","DeathBagInventory"])
	for patch: Node3D in foliage.patches.values():
		batches += patch.get_child_count()
	return {"biome":field.biome(player.global_position),"instances":foliage.instances,
		"grass":foliage.grass_instances,"visible_props":foliage.instances-foliage.grass_instances,
		"multimeshes":batches,"patches":foliage.patches.size(),"colliders":foliage.actors.size(),
		"patch_updates":foliage.patch_updates,"prop_deltas":ledger.props.size(),"destroyed":exhausted,
		"bags":bags,"farms":farms.plots.size(),"structures":building.pieces.size(),
		"support":building.last_benchmark,"containers":containers.records.size(),"mobs":mobs.report()}
