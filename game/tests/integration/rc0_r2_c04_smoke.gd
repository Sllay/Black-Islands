extends Node
var failures := 0
func check(ok: bool,label: String) -> void:
	if not ok:
		failures += 1
		push_error("RC0_R2_C04 "+label)
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	_settings()
	await _integrated()
	print("RC0_R2_C04 ","PASS" if failures == 0 else "FAIL"," failures=",failures)
	get_tree().quit(1 if failures else 0)
func _settings() -> void:
	GameSettings.path = "user://qa_r2_settings/"+Crypto.new().generate_random_bytes(6).hex_encode()+"/settings.json"
	GameSettings.current = GameSettings.defaults()
	var original := JSON.stringify(GameSettings.catalog)
	var previous := 0.0
	for quality: String in ["Low","Medium","High"]:
		var settings := GameSettings.defaults()
		settings.quality = quality
		var budget := GraphicsBudget.resolve(settings,GameSettings.catalog)
		check(budget.viewer_metres > previous and budget.foliage.density > 0,"profiles alter native budgets")
		previous = budget.viewer_metres
		settings.distance = 10
		settings.shadows = true
		settings.overrides.distance = true
		settings.overrides.shadows = true
		budget = GraphicsBudget.resolve(settings,GameSettings.catalog)
		check(budget.distance_level == 10 and budget.shadows,"custom overrides preserved")
	check(JSON.stringify(GameSettings.catalog) == original,"catalog immutable")
	var legacy := GameSettings.defaults()
	legacy.erase("overrides")
	legacy.quality = "Low"
	legacy.distance = 9
	check(GraphicsBudget.resolve(GraphicsBudget.migrate_settings(legacy),GameSettings.catalog).distance_level == 9,"R1 custom choices migrate intact")
	var options: Control = load("res://scenes/ui/Options.tscn").instantiate()
	add_child(options)
	var before := GameSettings.apply_count
	options._quality_selected("Low")
	check(options.staged.distance == 4 and GameSettings.apply_count == before and GameSettings.current.quality == "Medium","quality is staged, defaults update without expensive application")
	options.values.Distance.value = 10
	options._quality_selected("High")
	check(options.staged.distance == 10,"explicit custom distance survives preset selection")
	check(GameSettings.save(options.staged) == OK and GameSettings.effective().distance_level == 10,"confirm applies and persists")
	check(GameSettings.load_settings() == OK and GameSettings.effective().quality == "High","settings reload")
	options.queue_free()
	GameSettings.current = GameSettings.defaults()
	GameSettings.current.vsync = false
func _local(session: WorldSession) -> bool:
	var start := Time.get_ticks_msec()
	while Time.get_ticks_msec()-start < 25000:
		if session.pawn.spawned and session.terrain.is_editable(Vector3(-2,8,-2),.6):
			return true
		await get_tree().physics_frame
	return false
func _quantity(inventory: InventoryState, id: String) -> int:
	var total := 0
	for index: int in InventoryState.CAPACITY:
		var row := inventory.slot_at(index)
		if row.get("item_id") == id:
			total += int(row.quantity)
	return total
func _integrated() -> void:
	Profiles.library = FrontendLibrary.new("user://qa_r2_integrated/"+Crypto.new().generate_random_bytes(8).hex_encode())
	check(Profiles.library.create_world(1,"Chapter1 Native",8675309) == OK,"create final river world")
	check(Profiles.library.create_player(1,"Explorer",LPCCatalog.default_appearance()) == OK,"independent LPC player")
	Profiles.world_slot = 1
	Profiles.player_slot = 1
	var main: Node3D = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	var session: WorldSession = main.get_node("WorldRoot/WorldSession")
	check(await _local(session),"real Main native terrain/player locally ready")
	check(session.terrain.native.generator is VoxelGeneratorGraph and session.terrain.field.generation_version == 2,"production path uses v2 native graph")
	check(session.pawn.get_node("Viewer").view_distance == 192 and session.terrain.native.view_distance == 384,"distance units world metres vs native voxels")
	var inventory := session.pawn.inventory.state
	var old_wood := _quantity(inventory,"bi.resource.wood")
	check(InventoryTransactions.output(inventory,{"bi.resource.wood":11}).error == OK,"real inventory mutation")
	session.pawn.state.set_health(73)
	check(session.surface.building.place("r2_root","foundation",Vector3i(6,8,6)) == OK,"real footprint-supported structure")
	session.surface.objects.reconcile()
	session.surface.foliage.cut(Vector3(3,8,3),1.4)
	check(session.edits.apply(Vector3(-2,8,-2),.6) == OK,"native gameplay edit")
	var density := session.terrain.density_at(Vector3(-2,8,-2))
	check(session.edits.request(Vector3(300,20,300),.6) == OK and session.edits.pending_count() == 1,"remote unready intent queued")
	Flow._notification(NOTIFICATION_APPLICATION_PAUSED)
	check(session.edits.pending_count() == 0 and session.store.metrics().dirty_chunks == 0,"suspend cancels unexecuted intent and flushes accepted data")
	check(session.player_save.flush() == OK and session.store.metrics().dirty_chunks == 0,"explicit player/world save forces terrain checkpoint")
	var appearance := session.pawn.visual.configuration.duplicate(true)
	main.queue_free()
	await get_tree().process_frame
	await get_tree().physics_frame
	main = load("res://scenes/main/Main.tscn").instantiate()
	add_child(main)
	session = main.get_node("WorldRoot/WorldSession")
	check(await _local(session),"reopened real world locally ready")
	check(is_equal_approx(density,session.terrain.density_at(Vector3(-2,8,-2))),"terrain delta restored through native stream")
	check(session.surface.building.pieces.has("r2_root") and not session.surface.ledger.suppression.is_empty(),"structures/suppression restored")
	check(_quantity(session.pawn.inventory.state,"bi.resource.wood") == old_wood+11 and session.pawn.state.current_health == 73,"portable inventory/health unchanged on reload")
	check(AtomicDocument.same_value(appearance,session.pawn.visual.configuration),"LPC config restored without cached texture in save")
	check(session.frontend_save.world_document.schema == 2 and session.frontend_save.portable.document.schema == 2,"R1 schema2 preserved")
	print("R2_C04_INTEGRATED ",JSON.stringify(session.graphics_metrics()))
	main.queue_free()
	await get_tree().process_frame
