extends Node3D
var failures := 0
var player: PlayerActor

class RuntimeFixture extends SurfaceRuntime:
	var hole := AABB(Vector3(100,0,100),Vector3.ONE)
	func _density(point: Vector3) -> float:
		return 1.0 if hole.has_point(point) else point.y

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("RC0_C02 "+label)

func _ready() -> void:
	_run.call_deferred()

func frames(count: int) -> void:
	for frame: int in count:
		await get_tree().physics_frame

func _run() -> void:
	var floor_body := StaticBody3D.new()
	floor_body.collision_layer = CollisionLayers.WORLD
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(40,.2,40)
	collision.shape = shape
	collision.position.y = -.1
	floor_body.add_child(collision)
	add_child(floor_body)
	player = load("res://scenes/player/Player.tscn").instantiate()
	player.position.y = 2
	add_child(player)
	await frames(80)
	check(player.is_on_floor(),"physical capsule floor independent of visual")
	check(player.visual.sprite.billboard == BaseMaterial3D.BILLBOARD_FIXED_Y and player.visual.rotation.x == 0 and player.visual.sprite.offset.y == 28,"upright yaw-only visual anchored at feet")
	var original := player.transform
	player.camera_rig.tick(1)
	var overview_pitch := player.camera_rig.camera.rotation.x
	player.camera_rig.toggle_view()
	player.camera_rig.tick(1)
	check(not player.camera_rig.build_mode and player.camera_rig.blend == 1,"normal shoulder gameplay")
	player.camera_rig.toggle_build()
	player.camera_rig.tick(1)
	player.camera_rig.toggle_build()
	player.camera_rig.tick(1)
	check(player.camera_rig.blend == 1,"build returns previous shoulder preference")
	player.camera_rig.toggle_view()
	player.camera_rig.tick(1)
	player.camera_rig.toggle_build()
	player.camera_rig.tick(1)
	player.camera_rig.toggle_build()
	player.camera_rig.tick(1)
	check(player.camera_rig.blend == 0 and player.transform == original and overview_pitch < 0,"overview restored without actor transform change")
	player.targeter._set_hit(floor_body,Vector3(0,0,-2),Vector3.UP)
	check(player.targeter.current.available_actions.is_empty() and not player.targeter.interact(),"terrain ray is not an interaction")
	var runtime := RuntimeFixture.new()
	runtime.player = player
	runtime.containers = ContainerService.new()
	runtime.farms = FarmSystem.new(runtime.ledger)
	runtime.building = SupportGraph.new()
	runtime.building.ground = runtime.ground_contact
	runtime.building.foundation_ground = runtime.foundation_contact
	add_child(runtime)
	runtime.objects = SurfaceObjects.new()
	runtime.objects.runtime = runtime
	runtime.add_child(runtime.objects)
	runtime.farms.till(Vector3(0,0,-2),true,1)
	runtime.containers.create("bag",Vector3(0,0,-4),"WorldDropBag")
	runtime.objects.reconcile()
	await frames(3)
	check(not runtime.objects.views["0,0,-2"].has_node("Blocker") and not runtime.objects.views.bag.has_node("Blocker"),"farm and bag only query volumes")
	player.targeter._set_hit(runtime.objects.views.bag,Vector3(0,0,-4),Vector3.UP)
	check(&"open" in player.targeter.current.available_actions,"semantic container action")
	Input.action_press("move_up")
	await frames(90)
	Input.action_release("move_up")
	check(player.position.z < -5.5,"player passes through farm and bag")
	player.position = Vector3(0,.05,0)
	player.velocity = Vector3.ZERO
	var chest := runtime.containers.create("chest",Vector3(0,0,-3))
	InventoryTransactions.output(chest,{"bi.resource.stone":300})
	runtime.objects.reconcile()
	await frames(3)
	Input.action_press("move_up")
	await frames(60)
	Input.action_release("move_up")
	check(player.position.z > -2.7 and runtime.objects.views.chest.has_node("Blocker"),"chest physical collider separate from query")
	runtime.hole = AABB(Vector3(-1,-2,-4),Vector3(2,4,2))
	runtime.reconcile_container_support(runtime.hole)
	check(not runtime.containers.records.has("chest") and runtime.containers.records.has("broken_chest:chest"),"unsupported chest becomes bag")
	var bag: InventoryState = runtime.containers.inventories["broken_chest:chest"]
	var total := 0
	for index: int in InventoryState.CAPACITY:
		total += int(bag.slot_at(index).get("quantity",0))
	check(total == 300 and runtime.containers.break_chest("chest") != OK,"chest contents preserved once")
	_support()
	print("RC0_C02 ","PASS" if failures == 0 else "FAIL"," failures=",failures)
	get_tree().quit(1 if failures else 0)

func _support() -> void:
	var graph := SupportGraph.new()
	var removed := {"area":AABB(Vector3(100,0,100),Vector3.ONE)}
	graph.ground = func(cell: Vector3i) -> bool: return cell.y == 0 and cell.x in [0,8,100]
	graph.foundation_ground = func(cell: Vector3i) -> bool:
		return graph.ground.call(cell) and StructureModule.footprint_supported(cell,func(point: Vector3) -> bool: return not removed.area.has_point(point))
	check(graph.place("root","foundation",Vector3i.ZERO) == OK,"2m footprint root")
	check(SurfaceCatalog.data().structures.foundation.dimensions[0] == 2 and SurfaceCatalog.data().structures.foundation.dimensions[1] > SurfaceCatalog.data().structures.ceiling.dimensions[1],"correct area and thicker foundation")
	check(graph.place("overlap","foundation",Vector3i(1,0,1)) != OK,"overlapping logical cells share module occupancy")
	check(graph.place("c1","ceiling",Vector3i(2,0,0)) == OK and graph.place("c2","ceiling",Vector3i(4,0,0)) == OK,"two supported ceiling modules")
	check(graph.place("wall","wall",Vector3i(4,0,0)) == OK,"wall on cantilever")
	check(graph.place("double","wall",Vector3i(6,0,0),2) != OK,"same shared2m edge rejected")
	check(graph.place("fake_pillar","pillar",Vector3i(4,0,0)) == OK and graph.place("outward","ceiling",Vector3i(6,2,0)) != OK,"wall and floating pillar cannot reset reach")
	removed.area = AABB(Vector3(.7,-1,.7),Vector3(.6,2,.6))
	graph.terrain_changed(removed.area)
	check(graph.pieces.has("root"),"one unsupported footprint sample survives")
	check(graph.place("root_b","foundation",Vector3i(8,0,0)) == OK and graph.place("bridge","ceiling",Vector3i(6,0,0)) == OK,"alternate real root")
	graph.place("remote","foundation",Vector3i(100,0,0))
	removed.area = AABB(Vector3(-.1,-1,-.1),Vector3(2.2,2,2.2))
	graph.terrain_changed(removed.area)
	check(not graph.pieces.has("root") and graph.pieces.has("c2") and graph.pieces.has("remote"),"major excavation collapses root; alternate/remote support survives")
	check(graph.last_benchmark.examined < 8,"local indexed support scope")
	var previous := 0
	for tier: String in ["thatch","wood","stone","darkstone","scrap","iron"]:
		var hp := int(SurfaceCatalog.data().tiers[tier].hp)
		check(hp >= 5000 and hp > previous,"monotonic HP "+tier)
		previous = hp
	graph.foundation_ground = Callable()
	graph.ground = Callable()
	var adjacent := SupportGraph.new()
	adjacent.ground = func(_cell: Vector3i) -> bool: return true
	var foot := {"valid":true}
	adjacent.foundation_ground = func(_cell: Vector3i) -> bool: return foot.valid
	adjacent.place("foundation","foundation",Vector3i.ZERO)
	adjacent.place("deck","ceiling",Vector3i(2,0,0))
	adjacent.place("pillar","pillar",Vector3i(2,0,0))
	foot.valid = false
	adjacent.terrain_changed(AABB(Vector3(-1,-1,-1),Vector3(4,4,4)))
	check(not adjacent.pieces.has("foundation") and adjacent.pieces.has("deck"),"unsupported foundation cannot borrow pillar support; deck can")
