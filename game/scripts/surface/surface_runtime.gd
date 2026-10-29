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
	var point := Vector3(cell)+Vector3(.5,0,.5)
	if _density(point-Vector3.UP*.55) > 0 or _density(point+Vector3.UP*.55) < 0:
		return false
	var hit := terrain.surface_hit(point.x,point.z)
	if not hit.is_empty():
		return absf(float(hit.position.y)-cell.y) < .45 and hit.normal.y > .65
	# Far roots are validated against generator + authoritative sparse SDF,
	# never against another structure's collision layer.
	var low := point-Vector3.UP*.25
	var high := point+Vector3.UP*.45
	return _density(low) < 0 and _density(high) > 0

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
	var button := ShellUI.button("P04 • cultivo / construção QA","SurfaceQA",Vector2(330,44))
	button.pressed.connect(qa.c02)
	session.tools.add_child(button)

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

func _process(delta: float) -> void:
	if player == null or not player.spawned or player.inventory.is_open:
		return
	ledger.clock += delta
	ledger.active_seconds += delta
	_elapsed += delta
	if _elapsed >= 1:
		_elapsed = 0
		_tick_domains()
		for key: String in ledger.suppression.keys():
			var row: Dictionary = ledger.suppression[key]
			if row.reasons.is_empty() and ledger.clock >= float(row.regrow_at):
				var parts := key.split(",")
				ledger.suppression.erase(key)
				refresh(Vector3(float(parts[0]),float(parts[1]),float(parts[2])))

func primary_action() -> void:
	actions.primary()

func qa_resource(kind: String, tool_id: String) -> Dictionary:
	# Explicit QA uses the same validation/output path as production intent.
	for id: String in candidates:
		var row: Dictionary = candidates[id]
		if definition(row.definition).harvest != kind or destroyed(id):
			continue
		var point := Vector3(row.point[0],row.point[1],row.point[2])
		if point.distance_to(player.global_position) > 8:
			continue
		player.motor.request_spawn(point+Vector3(0,2,2))
		for slot: int in InventoryState.CAPACITY:
			if player.inventory.state.slot_at(slot).get("item_id") == tool_id:
				player.inventory.state.assign_hotbar(4,slot)
				player.inventory.state.select_hotbar(4)
		return {"id":id,"result":harvest_prop(id,player)}
	return {"error":ERR_DOES_NOT_EXIST}

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
		var hit := terrain.surface_hit(point.x,point.z)
		if _density(point-Vector3.UP*.3) > 0 or hit.is_empty() or absf(float(hit.position.y)-point.y) > .5:
			create_bag(point,farms.remove(key,true))
			refresh(point)
	for row: Dictionary in building.terrain_changed(area):
		if row.definition == "foundation":
			var point := Vector3(SupportGraph.cell(row))+Vector3(.5,.05,.5)
			ledger.release(point,"foundation:"+row.id)
			refresh(point)
	objects.reconcile()

func snapshot() -> Dictionary:
	var data := ledger.snapshot()
	data.farms = farms.plots.duplicate(true)
	data.structures = building.pieces.duplicate(true)
	data.containers = containers.snapshot()
	return data

func report() -> Dictionary:
	var exhausted := 0
	for id: String in ledger.props:
		if destroyed(id):
			exhausted += 1
	return {"biome":field.biome(player.global_position),"instances":foliage.instances,
		"grass":foliage.grass_instances,"patches":foliage.patches.size(),"colliders":foliage.actors.size(),
		"patch_updates":foliage.patch_updates,"prop_deltas":ledger.props.size(),"destroyed":exhausted,"bags":ledger.bags.size()}
