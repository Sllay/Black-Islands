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

func configure(session: WorldSession, restored: Dictionary = {}) -> void:
	player = session.pawn
	terrain = session.terrain
	field = PropField.new(terrain.field)
	# Existing P02 edits must also invalidate procedurally positioned foliage.
	for voxel: Vector3i in session.store.snapshot_box(Vector3i(-960,-256,-960),Vector3i(1920,768,1920)):
		var point := Vector3(voxel)*WorldCoordinates.VOXEL_SIZE
		edited_patches[Vector2i(floori(point.x/16),floori(point.z/16))] = true
	for row: Dictionary in SurfaceCatalog.data().props:
		_definitions[row.id] = row
	if not restored.is_empty():
		assert(ledger.restore(restored) == OK)
	add_to_group("surface_runtime")
	foliage = FoliagePresenter.new()
	foliage.runtime = self
	add_child(foliage)
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
	var actions := ["bi.tool.axe","bi.tool.knife","bi.tool.hoe","bi.tool.watering_can"]
	for slot: int in range(InventoryState.CAPACITY):
		var row := player.inventory.state.slot_at(slot)
		if row.get("item_id","") in actions:
			player.inventory.state.assign_hotbar(4+actions.find(row.item_id),slot)
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
		for key: String in ledger.suppression.keys():
			var row: Dictionary = ledger.suppression[key]
			if row.reasons.is_empty() and ledger.clock >= float(row.regrow_at):
				var parts := key.split(",")
				ledger.suppression.erase(key)
				refresh(Vector3(float(parts[0]),float(parts[1]),float(parts[2])))

func primary_action() -> void:
	var target := player.targeter.current
	if is_instance_valid(target.entity) and target.entity is PropActor:
		harvest_prop(target.entity.spawn_id,player)

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
	var bag := InventoryState.new()
	bag.inventory_id = ledger.new_id("drop")
	bag.owner_scope = "WORLD"
	InventoryTransactions.output(bag,contents)
	ledger.bags[bag.inventory_id] = {"id":bag.inventory_id,"position":[point.x,point.y,point.z],"inventory":bag.snapshot(),"deadline":-1,"policy":"WorldDropBag"}
	return bag.inventory_id

func refresh(point: Vector3) -> void:
	foliage.invalidate(AABB(point-Vector3(1,2,1),Vector3(3,4,3)))

func terrain_changed(area: AABB) -> void:
	for key: Vector2i in foliage.patches:
		if AABB(Vector3(key.x*16,-128,key.y*16),Vector3(16,384,16)).intersects(area):
			edited_patches[key] = true
	await get_tree().create_timer(.5).timeout
	foliage.invalidate(area)

func snapshot() -> Dictionary:
	return ledger.snapshot()

func report() -> Dictionary:
	var exhausted := 0
	for id: String in ledger.props:
		if destroyed(id):
			exhausted += 1
	return {"biome":field.biome(player.global_position),"instances":foliage.instances,
		"grass":foliage.grass_instances,"patches":foliage.patches.size(),"colliders":foliage.actors.size(),
		"patch_updates":foliage.patch_updates,"prop_deltas":ledger.props.size(),"destroyed":exhausted,"bags":ledger.bags.size()}
