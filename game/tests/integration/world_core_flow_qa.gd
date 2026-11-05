extends Node
## Persistent QA driver: real Boot/menu/world/player/Main, production services only.
var history: Array[String] = []
var session: WorldSession
var loose_id := ""
var proofs: Dictionary = {}
var performance: Dictionary = {}
var _saved: Dictionary = {}
func _ready() -> void: _boot.call_deferred()
func _boot() -> void:
	name = "WorldCoreFlowQA"
	Profiles.library = FrontendLibrary.new("user://qa_c04_flow/"+Crypto.new().generate_random_bytes(8).hex_encode())
	GameSettings.path = Profiles.library.directory.path_join("settings.json")
	get_tree().current_scene = null
	get_tree().change_scene_to_file("res://scenes/boot/Boot.tscn")
	await get_tree().create_timer(.5).timeout
	history = ["Boot",get_tree().current_scene.scene_file_path]
	print("WORLD_CORE_FLOW_READY ",history)
func qa_create() -> Dictionary:
	GameSettings.current = GameSettings.defaults()
	GameSettings.current.quality = "Low"
	GameSettings.current.distance = 2
	GameSettings.current.overrides.distance = true
	var world: Error = Profiles.library.create_world(5,"World Core Proof",424242)
	var player: Error = Profiles.library.create_player(5,"Foundation Explorer",LPCCatalog.default_appearance())
	Flow.show_worlds()
	history.append("Worlds")
	return {"world":world,"player":player}
func qa_choose_world() -> void:
	Profiles.world_slot = 5
	Flow.show_players()
	history.append("PlayerProfiles")
func qa_play() -> void:
	Profiles.player_slot = 5
	Flow.enter_main()
	history.append("Main")
func _session() -> WorldSession:
	if get_tree().current_scene == null: return null
	session = get_tree().current_scene.get_node_or_null("WorldRoot/WorldSession") as WorldSession
	return session
func report() -> Dictionary:
	if _session() == null: return {"history":history,"scene":get_tree().current_scene.scene_file_path}
	return {"history":history,"ready":session.pawn.spawned,"position":session.pawn.global_position,"calendar":session.surface.core.clock.snapshot(),"weather":session.surface.core.weather.state,"proofs":proofs,"performance":performance,"rain":session.surface.core.last_rain,"renderer_instances":session.surface.weather_view.rain.multimesh.instance_count,"crosshair":InteractionFeedback.State.keys()[session.pawn.targeter.feedback]}
func qa_shore() -> Dictionary:
	var field := session.terrain.field as WorldFieldV2
	var lake: Dictionary = field.lakes[0]
	var center := Vector2(lake.center[0],lake.center[1])
	var best := Vector3.ZERO
	var error := INF
	for factor: float in [.9,1.05,1.15,1.25]:
		for step: int in 24:
			var point := center+Vector2.RIGHT.rotated(step*TAU/24)*float(lake.radius)*factor
			var height := field.top_surface(point.x,point.y)
			var score := absf(height-float(lake.level)-.5)
			if score < error:
				error = score
				best = Vector3(point.x,height+.1,point.y)
	session.pawn.inspect_at(best)
	return {"shore":best,"lake":lake.id if lake.has("id") else center,"level":lake.level}
func qa_objects() -> Dictionary:
	var surface := session.surface
	var point := session.pawn.global_position
	var field := session.terrain.field
	var parcel := point+Vector3(-1,0,-1.8)
	parcel.y = field.top_surface(parcel.x,parcel.z)+.03
	var chest_point := point+Vector3(1.8,0,-1.3)
	chest_point.y = field.top_surface(chest_point.x,chest_point.z)+.03
	var inventory := session.pawn.inventory.state
	InventoryTransactions.output(inventory,{"bi.resource.wood":20})
	var uid := ""
	for slot: int in 20:
		if inventory.slot_at(slot).get("item_id") == "bi.resource.wood": uid = inventory.slot_at(slot).stack_uid
	if uid.is_empty(): return {"error":"QA wood is pending; free a slot using production inventory"}
	var drops := session.pawn.inventory.simulation.drops
	var prior := drops.point_for
	drops.point_for = func(_store: InventoryState) -> Vector3: return parcel
	var before: Array = surface.containers.records.keys()
	var start := Time.get_ticks_usec()
	var dropped := drops.drop(inventory,uid,5,inventory.revision)
	drops.point_for = prior
	for id: String in surface.containers.records:
		if id not in before and surface.containers.records[id].kind == "LooseItemDrop": loose_id = id
	var chest := surface.containers.create("qa.c04.chest",chest_point)
	InventoryTransactions.output(chest,{"bi.resource.stone":7})
	var bag := surface.containers.create("qa.c04.bag",chest_point+Vector3(1.0,0,1.5),"WorldDropBag")
	InventoryTransactions.output(bag,{"bi.resource.wood":2,"bi.resource.meat":2})
	var death_source := InventoryState.new()
	death_source.add_item("bi.resource.fiber",2)
	drops.publish_all(death_source,chest_point+Vector3(0,0,2.2),"qa.c04.death","DeathBagInventory","qa.c04.death")
	var plot := point+Vector3(-1,0,1)
	plot.y = field.top_surface(plot.x,plot.z)+.02
	surface.farms.till(plot,true,2)
	surface.objects.reconcile()
	performance.drop_bag_setup_us = Time.get_ticks_usec()-start
	proofs.dropped = dropped
	return {"drop":dropped,"loose":loose_id,"chest":chest_point,"farm":plot,"containers":surface.containers.records.size()}
func qa_target(id: String) -> Dictionary:
	var view: SurfaceObject = session.surface.objects.views.get(id)
	if view == null: return {"error":"view not resident","id":id}
	var rig := session.pawn.camera_rig
	rig.gameplay_mode = PlayerCameraRig.GameplayMode.SHOULDER
	rig._keep_aim = false
	rig.tick(1)
	rig.aim_screen = rig.camera.unproject_position(view.global_position)/get_viewport().get_visible_rect().size
	var start := Time.get_ticks_usec()
	var result := session.pawn.targeter.probe(session.pawn.motor.facing)
	performance.target_probe_us = Time.get_ticks_usec()-start
	proofs.target_matches_ray = result.entity == view
	return {"match":result.entity == view,"actions":result.available_actions,"aim_screen":rig.aim_screen,"distance":result.distance,"feedback":InteractionFeedback.State.keys()[session.pawn.targeter.feedback]}
func qa_pickup() -> Dictionary:
	var target := qa_target(loose_id)
	var accepted := session.pawn.targeter.interact()
	proofs.pickup = accepted and not session.surface.containers.records.has(loose_id)
	return {"target":target,"accepted":accepted,"removed":not session.surface.containers.records.has(loose_id)}
func qa_chest(open: bool) -> Dictionary:
	var start := Time.get_ticks_usec()
	if open:
		qa_target("qa.c04.chest")
		session.pawn.targeter.interact()
	else:
		if session.pawn.inventory.is_open: session.pawn.inventory.toggle()
	performance.chest_request_us = Time.get_ticks_usec()-start
	var accepted := session.surface.containers.is_open("qa.c04.chest")
	var view: ContainerVisual = session.surface.objects.views["qa.c04.chest"].get_node("ContainerVisual")
	proofs["chest_open" if open else "chest_closed"] = accepted == open and view.state == ("OPEN" if open else "CLOSED")
	return {"accepted_open":accepted,"visual":view.state,"angle":view.lid.rotation.x}
func qa_environment(fraction: float, weather_id: String) -> Dictionary:
	session.surface.qa_world_state(fraction,weather_id)
	session.surface.core.clock.paused = true
	return {"period":session.surface.core.clock.period,"weather":session.surface.core.weather.state}
func qa_rain() -> Dictionary:
	var core := session.surface.core
	core.clock.paused = false
	core.weather.set_state("RAIN",core.clock.elapsed_game_seconds)
	session.water.domain.ensure_near(session.pawn.global_position,9)
	var before := session.water.domain.grid.external_volume
	core.advance(1)
	core.clock.paused = true
	proofs.rain_water = session.water.domain.grid.external_volume > before
	proofs.rain_farm = core.last_rain.farms > 0
	performance.clock_us = core.metrics.clock_us
	performance.weather_us = core.metrics.weather_us
	performance.rain_us = core.metrics.rain_us
	return {"rain":core.last_rain,"external_delta":session.water.domain.grid.external_volume-before,"proofs":proofs}
func qa_lightning() -> Dictionary:
	var core := session.surface.core
	core.weather.set_state("THUNDERSTORM",core.clock.elapsed_game_seconds)
	core.clock.paused = false
	core.advance(20)
	core.clock.paused = true
	proofs.lightning = core.weather.lightning_sequence > 0
	return {"sequence":core.weather.lightning_sequence,"state":core.weather.state}
func qa_save_reload() -> Dictionary:
	session.surface.core.clock.paused = true
	var result := session.frontend_save.flush()
	_saved = {"clock":session.surface.core.clock.elapsed_game_seconds,"weather":session.surface.core.weather.snapshot(),"chest_uid":session.surface.containers.inventories["qa.c04.chest"].slot_at(0).stack_uid,"world_id":session.surface.core.clock.world_id}
	proofs.save = result == OK
	Flow.show_menu()
	await get_tree().create_timer(.3).timeout
	Flow.enter_main()
	return {"save":result,"reloading":true}
func qa_check_reload() -> Dictionary:
	if _session() == null or not session.pawn.spawned: return {"ready":false}
	proofs.reload_clock = is_equal_approx(session.surface.core.clock.elapsed_game_seconds,float(_saved.clock))
	proofs.reload_weather = session.surface.core.weather.state == _saved.weather.state and str(session.surface.core.weather.rng.state) == _saved.weather.rng_state
	proofs.reload_container_uid = session.surface.containers.inventories["qa.c04.chest"].slot_at(0).stack_uid == _saved.chest_uid
	proofs.reload_no_loose_duplicate = not session.surface.containers.records.has(loose_id)
	return {"ready":true,"proofs":proofs}
