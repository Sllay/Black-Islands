extends Node
## Isolated QA profiles, production Main/voxel/LPC/harvest/inventory/save paths.
var main: Node
var session: WorldSession
var selected := ""
var last_result: Dictionary = {}
func _ready() -> void:
	Engine.max_fps = 60
	_start.call_deferred()
func _start() -> void:
	GameSettings.current = GameSettings.defaults()
	GameSettings.current.quality = "Low"
	GameSettings.current.distance = 2
	GameSettings.current.overrides.distance = true
	Profiles.library = FrontendLibrary.new("user://qa_content_world/"+Crypto.new().generate_random_bytes(8).hex_encode())
	Profiles.library.create_world(1,"Content Foundation",424242)
	Profiles.library.create_player(1,"Content Explorer",LPCCatalog.default_appearance())
	Profiles.world_slot = 1
	Profiles.player_slot = 1
	main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	session = main.get_node("WorldRoot/WorldSession")
	print("CONTENT_WORLD Main loaded")
func qa_equip(detached: bool = true) -> Dictionary:
	var inventory := session.pawn.inventory.state
	var id := "bi.weapon.test_blade" if detached else "bi.weapon.starter_sword"
	var found := false
	for slot: int in 20:
		if inventory.slot_at(slot).get("item_id") == id: found = true
	if not found and not inventory._slots.has(null): return {"error":"inventory full; recover the existing world drop or free a slot"}
	if not found:
		var plan := InventoryPlan.new()
		InventoryCommands.output(plan.include(inventory),id,1)
		plan.commit()
	for slot: int in 20:
		if inventory.slot_at(slot).get("item_id") == id:
			inventory.assign_hotbar(0,slot)
			inventory.select_hotbar(0)
	return session.pawn.weapon_rig.report()
func qa_focus_prop(definition: String) -> Dictionary:
	var surface := session.surface
	var nearest := INF
	var chosen := ""
	for id: String in surface.candidates:
		var candidate: Dictionary = surface.candidates[id]
		if candidate.definition != definition or surface.destroyed(id): continue
		var candidate_point := Vector3(candidate.point[0],candidate.point[1],candidate.point[2])
		var distance := candidate_point.distance_squared_to(session.pawn.global_position)
		if distance < nearest:
			nearest = distance
			chosen = id
	if chosen.is_empty(): return {"error":"not resident yet","candidates":surface.candidates.size()}
	selected = chosen
	var row: Dictionary = surface.candidates[chosen]
	var point := Vector3(row.point[0],row.point[1],row.point[2])
	session.pawn.inspect_at(point+Vector3(0,.1,2))
	session.pawn.motor.facing = Vector3.FORWARD
	var inventory := session.pawn.inventory.state
	for slot: int in 20:
		if inventory.slot_at(slot).get("item_id") == "bi.tool.stone_pick":
			inventory.assign_hotbar(1,slot)
			inventory.select_hotbar(1)
	return {"id":selected,"definition":definition,"point":point,"distance":sqrt(nearest)}
func qa_strike(critical: bool = false) -> Dictionary:
	if selected.is_empty(): return {}
	last_result = session.surface.harvest_prop(selected,session.pawn,critical)
	return {"result":last_result,"inventory":session.pawn.inventory.state.snapshot(),"domain":session.surface.ledger.props.get(selected,{})}
func report() -> Dictionary:
	return {"ready":session.pawn.spawned,"position":session.pawn.global_position,"props":session.surface.candidates.size(),"foliage":session.surface.foliage.report(),"weapon":session.pawn.weapon_rig.report(),"last_harvest":last_result,"content_schemas":1,"graph":session.terrain.native.generator.get_class()}
