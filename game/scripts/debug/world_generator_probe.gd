class_name WorldGeneratorProbe
extends Node3D
## R2 QA only: actual native terrain, overview camera, sparse edit/reload proof.
var field: WorldFieldV2
var terrain: VoxelTerrainAdapter
var viewer: VoxelViewer
var waters: GeneratedWaterView
var store: WorldDeltaStore
var edits: TerrainEditService
var camera: Camera3D
var result: Dictionary = {}
var directory := "user://qa_r2_overviews/"+Crypto.new().generate_random_bytes(6).hex_encode()

func _ready() -> void:
	var shell: Node3D = load("res://scenes/world/WorldSession.tscn").instantiate()
	shell.set_script(null)
	shell.get_node("Lake").visible = false
	add_child(shell)
	camera = Camera3D.new()
	camera.position = Vector3(0,820,690)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 1000
	camera.far = 5000
	add_child(camera)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	set_seed(424242)

func set_seed(seed_value: int) -> void:
	if store is BufferedWorldDeltaStore:
		assert(store.flush() == OK)
	if is_instance_valid(terrain):
		remove_child(terrain)
		terrain.queue_free()
		remove_child(viewer)
		viewer.queue_free()
		remove_child(waters)
		waters.queue_free()
	field = WorldFieldV2.new(seed_value)
	var profile := {"save_id":"22222222222222222222222222222222","created_at":"2026-10-30T00:00:00Z",
		"world_seed":seed_value,"world_generation_version":2,"world_profile":field.profile_id}
	store = BufferedWorldDeltaStore.new(directory.path_join(str(seed_value)),profile)
	assert(store.load_world() == OK)
	terrain = load("res://scenes/world/WorldTerrain.tscn").instantiate()
	terrain.name = "NativeTerrain"
	terrain.field = field
	terrain.deltas = store
	add_child(terrain)
	# Overview-only outer distance, gameplay still has its own smaller budgets.
	terrain.native.view_distance = 2304
	viewer = VoxelViewer.new()
	viewer.name = "OverviewViewer"
	viewer.view_distance = 2304
	viewer.position = Vector3(0,9,0)
	add_child(viewer)
	waters = GeneratedWaterView.new()
	waters.name = "GeneratedWater"
	waters.field = field
	add_child(waters)
	WorldBoundary.configure_field(field)
	edits = TerrainEditService.new()
	edits.terrain = terrain
	edits.store = store
	print("R2_OVERVIEW ",JSON.stringify(field.metadata))

func report() -> Dictionary:
	return {"world":field.metadata,"native_generator":terrain.native.generator.get_class(),"terrain":terrain.statistics(),"delta":store.metrics(),"result":result}

func edit_probe() -> void:
	var before := terrain.surface_hit(0,0)
	var error := edits.apply(Vector3(0,8,0),1.2)
	if store is BufferedWorldDeltaStore and error == OK:
		error = store.flush()
	await get_tree().create_timer(1).timeout
	var after := terrain.surface_hit(0,0)
	result = {"edit":error,"before":before.get("position"),"after":after.get("position"),"delta":store.metrics()}
	print("R2_C01_EDIT ",result)

func reopen() -> void:
	var seed_value := field.world_seed
	set_seed(seed_value)
