extends Node3D
var failures := 0
var assertions := 0
func check(ok: bool, text: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("WORLD_CORE_A "+text)
func _ready() -> void: _run.call_deferred()
func _run() -> void:
	var actor: PlayerActor = load("res://scenes/player/Player.tscn").instantiate()
	actor.position = Vector3.ZERO
	add_child(actor)
	actor.set_physics_process(false)
	var rig := actor.camera_rig
	rig.tick(1)
	check(not InteractionFeedback.precision(actor),"overview hides crosshair")
	rig.toggle_view()
	rig.tick(1)
	check(InteractionFeedback.precision(actor),"shoulder precision policy")
	var screen_size := get_viewport().get_visible_rect().size
	var body_screen := rig.camera.unproject_position(actor.position+Vector3.UP)
	check(absf(body_screen.x-screen_size.x*rig.aim_screen.x) > screen_size.x*.08,"shoulder actor offset from aim")
	var marker := StaticBody3D.new()
	marker.position = Vector3(0,1,-2)
	marker.collision_layer = CollisionLayers.QUERY
	marker.add_to_group("interactables")
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = .5
	shape.shape = sphere
	marker.add_child(shape)
	add_child(marker)
	rig.aim_screen = rig.camera.unproject_position(marker.position)/screen_size
	await get_tree().physics_frame
	await get_tree().physics_frame
	var acquired := actor.targeter.probe(Vector3.FORWARD)
	check(acquired.entity == marker,"ray uses real aim_screen")
	var crosshair: InteractionCrosshair = actor.get_node("InteractionOverlay/InteractionCrosshair")
	crosshair._process(0)
	check(crosshair.point.is_equal_approx(rig.aim_screen*crosshair.size) and crosshair.mouse_filter == Control.MOUSE_FILTER_IGNORE,"crosshair projection and touch pass-through")
	actor.targeter.current.available_actions = [&"open"]
	check(InteractionFeedback.resolve(actor) == InteractionFeedback.State.INTERACTABLE,"available action feedback")
	actor.targeter.current.available_actions.clear()
	check(InteractionFeedback.resolve(actor) == InteractionFeedback.State.DEFAULT,"no fake terrain interaction")
	marker.add_to_group("combat_targets")
	actor.targeter._set_hit(marker,marker.position,Vector3.UP)
	check(InteractionFeedback.resolve(actor) == InteractionFeedback.State.COMBAT_TARGET,"combat feedback")
	actor.targeter.current.clear()
	actor.targeter.aim_out_of_range = true
	check(InteractionFeedback.resolve(actor) == InteractionFeedback.State.OUT_OF_RANGE,"range feedback")
	actor.targeter.aim_out_of_range = false
	var surface := SurfaceRuntime.new()
	surface.player = actor
	surface.building = SupportGraph.new()
	surface.building.ground = func(_cell: Vector3i) -> bool: return true
	surface.actions = SurfaceActions.new(surface)
	actor.inventory.state.add_item("bi.resource.wood",20)
	actor.camera_rig.build_mode = true
	actor.targeter.current.kind = TargetResult.Kind.BUILD_GRID
	actor.targeter.current.entity = null
	actor.targeter.current.world_position = Vector3.ZERO
	actor.targeter.current.build_cell = Vector3i.ZERO
	actor.targeter.current.distance = 2
	var revision := actor.inventory.state.revision
	check(InteractionFeedback.resolve(actor,surface) == InteractionFeedback.State.BUILD_VALID,"real support/payment preview valid")
	check(surface.building.pieces.is_empty() and actor.inventory.state.revision == revision,"preview has no domain side effect")
	surface.building.place("occupied","foundation",Vector3i.ZERO)
	check(InteractionFeedback.resolve(actor,surface) == InteractionFeedback.State.BUILD_INVALID,"occupied socket feedback invalid")
	actor.camera_rig.build_mode = false
	var before := actor.transform
	rig.toggle_view()
	for step: int in 24: rig.tick(1.0/60)
	check(rig.blend == 0 and actor.transform == before,"reversible camera transition keeps body")
	var start := Time.get_ticks_usec()
	for index: int in 100: surface.building.preview("wall",Vector3i.ZERO)
	print("WORLD_CORE_A ","PASS" if failures == 0 else "FAIL"," assertions=",assertions," failures=",failures," preview100_us=",Time.get_ticks_usec()-start)
	surface.free()
	get_tree().quit(1 if failures else 0)
