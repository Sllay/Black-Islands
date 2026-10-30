extends Node
## Isolated QA data, production Main/WorldSession/player/terrain/save components.
var main: Node
var session: WorldSession
var failures := 0
var evidence: Dictionary = {}
func _ready() -> void:
	Engine.max_fps = 60
	_start.call_deferred()
func _start() -> void:
	if OS.get_environment("R3_WATER_QUALITY") in ["Low","Medium","High"]:
		GameSettings.current = GameSettings.defaults()
		GameSettings.current.quality = OS.get_environment("R3_WATER_QUALITY")
	Profiles.library = FrontendLibrary.new("user://qa_r3_gameplay/"+Crypto.new().generate_random_bytes(8).hex_encode())
	assert(Profiles.library.create_world(1,"Water Foundation",8675309) == OK)
	assert(Profiles.library.create_player(1,"Water Explorer",LPCCatalog.default_appearance()) == OK)
	Profiles.world_slot = 1
	Profiles.player_slot = 1
	main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	session = main.get_node("WorldRoot/WorldSession")
	qa_lake()
	print("R3_WATER_WORLD production Main initialized")
	if OS.get_environment("R3_WATER_WORLD_SMOKE") == "1":
		_backend_smoke()
func qa_lake() -> void:
	var lake := session.terrain.field.lake_body()
	var point := Vector3(lake.center.x,lake.level+.1,lake.center.y+float(lake.radius)*.65)
	session.water.domain.ensure_near(point)
	session.pawn.inspect_at(point)
func qa_river() -> void:
	var points: Array = session.terrain.field.river.get("points",[])
	if points.is_empty():
		return
	var row: Array = points[mini(3,points.size()-1)]
	var point := Vector3(row[0],row[1]+.2,row[2])
	session.water.domain.ensure_near(point)
	session.pawn.inspect_at(point)
func qa_strike() -> Dictionary:
	var point := session.water.domain.grid.point_at(session.water.domain.grid.cell_at(session.pawn.position))
	var before := session.water.sample(point)
	point.y = float(before.level)-float(before.depth)+.2
	var started := Time.get_ticks_usec()
	var error := session.edits.apply(point,2)
	evidence = {"error":error,"before":before,"after":session.water.sample(point),"edit_invalidation_ms":(Time.get_ticks_usec()-started)/1000.0,"dirty_cells":session.water.domain.last_invalidation_cells,"io":session.store.metrics()}
	print("R3_WATER_TERRAIN ",JSON.stringify(evidence))
	return evidence
func report() -> Dictionary:
	return {"water":session.water.domain.grid.report(),"sample":session.water.sample(session.pawn.position),"swimming":session.pawn.motor.water_motion.swimming,"edit":evidence,"graphics":session.graphics_metrics(),"save_error":session.player_save.flush(),"presentation":_presentation()}

func _presentation() -> Dictionary:
	for node: Node in main.find_children("*","Node3D",true,false):
		if node is WaterRenderer:
			return node.report()
	return {}

func ocean_report() -> Dictionary:
	var before := session.water.domain.grid.tiles.size()
	var result := session.water.sample(Vector3(900,-1,900))
	return {"query":result,"tiles_before":before,"tiles_after":session.water.domain.grid.tiles.size(),"ocean_grid_allocated":session.water.domain.grid.tiles.size()-before}

func _backend_smoke() -> void:
	for frame: int in 8:
		await get_tree().process_frame
	var lake := session.water.sample(session.pawn.global_position)
	if lake.kind != "lake" or lake.depth <= 0 or not session.pawn.visual.get_node("Sprite3D") is Sprite3D:
		failures += 1
	var ocean := ocean_report()
	if ocean.query.kind != "ocean" or ocean.ocean_grid_allocated != 0:
		failures += 1
	qa_river()
	for frame: int in 8:
		await get_tree().process_frame
	var river := session.water.sample(session.pawn.global_position)
	if river.kind != "river" or river.depth <= 0 or river.current.is_zero_approx():
		failures += 1
	var result := {"rendering_method":RenderingServer.get_current_rendering_method(),"quality":GameSettings.effective().quality,"lake":lake,"river":river,"ocean":ocean,"water":session.water.domain.grid.report(),"presentation":_presentation()}
	print("R3_WATER_WORLD_RESULT ",JSON.stringify(result))
	print("R3_WATER_WORLD_SMOKE ","PASS" if failures == 0 else "FAIL"," failures=",failures," rendering_method=",RenderingServer.get_current_rendering_method())
	get_tree().quit(1 if failures else 0)
