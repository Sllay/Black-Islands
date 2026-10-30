extends Node
## Production Main/player/voxel/session, isolated QA profiles. No water benchmark.
var main: Node
var session: WorldSession
func _ready() -> void:
	Engine.max_fps = 60
	_start.call_deferred()
func _start() -> void:
	GameSettings.current = GameSettings.defaults()
	GameSettings.current.quality = "Low"
	GameSettings.current.distance_level = 2
	Profiles.library = FrontendLibrary.new("user://qa_r3_inventory_world/"+Crypto.new().generate_random_bytes(8).hex_encode())
	assert(Profiles.library.create_world(1,"Inventory Foundation",424242) == OK)
	assert(Profiles.library.create_player(1,"Inventory Explorer",LPCCatalog.default_appearance()) == OK)
	Profiles.world_slot = 1
	Profiles.player_slot = 1
	main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	session = main.get_node("WorldRoot/WorldSession")
	print("R3_INVENTORY_WORLD Main loaded")
func qa_open_bench() -> Dictionary:
	if not session.pawn.spawned:
		return {"ready":false}
	var player := session.pawn
	var point := player.global_position+Vector3(2,0,0)
	var hit := session.terrain.surface_hit(point.x,point.z)
	if hit.is_empty():
		return {"ready":false}
	point.y = hit.position.y+.02
	var bench := session.surface.containers.create("qa.workbench",point,"Workbench")
	InventoryTransactions.output(bench,{"bi.resource.wood":64,"bi.resource.stone":32})
	session.surface.objects.reconcile()
	session.surface.container_opened.emit("qa.workbench")
	return report()
func report() -> Dictionary:
	return {"ready":session.pawn.spawned,"feet":session.pawn.global_position,"world_version":session.store.identity.world_generation_version,"voxel_graph":session.terrain.native.generator.get_class(),"inventory_slots":session.pawn.inventory.state._slots.size(),"queue":session.pawn.inventory.crafting.service.queue.snapshot(),"crafts":session.pawn.inventory.crafting.service.completions,"world_containers":session.surface.containers.inventories.size()}
