class_name SurfaceQA
extends Node
## Explicit debug acceleration on the actual session/services, not a second game.
var runtime: SurfaceRuntime
var result: Dictionary = {}
var spawned_ids: Array[String] = []
var farm_offset := Vector3(3,0,3)

func c03() -> void:
	spawned_ids.clear()
	var placements := [Vector3(-4,0,-4),Vector3(5,0,-3),Vector3(7,0,-7)]
	var definitions := ["chicken","boar","zombie"]
	for index: int in range(3):
		var point: Vector3 = runtime.player.position+placements[index]
		point.y = runtime.terrain.field.top_surface(point.x,point.z)+.05
		var id := runtime.ledger.new_id("mob")
		runtime.mobs.domain.spawn(id,definitions[index],point)
		spawned_ids.append(id)
	runtime.mobs.reconcile()
	result = {"spawned":spawned_ids.duplicate(),"mobs":runtime.mobs.report()}

func combat_sample() -> void:
	runtime.player.state.set_health(100)
	runtime.player.combat.cancel()
	runtime.player.inventory.state.select_hotbar(0)
	runtime.player.motor.facing = Vector3.FORWARD
	var id := runtime.ledger.new_id("combat_mob")
	var point := runtime.player.position+Vector3.FORWARD*1.4
	var hit := runtime.terrain.surface_hit(point.x,point.z)
	if not hit.is_empty():
		point.y = hit.position.y+.05
	runtime.mobs.domain.spawn(id,"chicken",point)
	runtime.mobs.reconcile()
	await get_tree().physics_frame
	var before := runtime.player.combat.attacks_started
	Input.action_press("attack_primary")
	await get_tree().create_timer(.4).timeout
	var held_count := runtime.player.combat.attacks_started-before
	Input.action_release("attack_primary")
	await get_tree().create_timer(1.2).timeout
	runtime.mobs.domain.evaluate()
	result = {"id":id,"hold_attacks":held_count,"released_attacks":runtime.player.combat.attacks_started-before,
		"life":runtime.mobs.domain.states[id].life,"health":runtime.mobs.domain.states[id].health}
	print("P04_NATIVE_COMBAT ",result)
	if runtime.mobs.domain.states[id].life == "CORPSE":
		runtime.container_opened.emit(runtime.mobs.domain.states[id].corpse_inventory)

func offscreen_sample() -> void:
	var id := runtime.ledger.new_id("offscreen_mob")
	var point := runtime.player.position+Vector3(2,0,0)
	runtime.mobs.domain.spawn(id,"chicken",point)
	var hit := HitPayload.new()
	hit.raw_damage = 5
	runtime.mobs.domain.hit(id,hit)
	runtime.mobs.reconcile()
	runtime.player.inspect_at(Vector3(150,40,0))
	await get_tree().create_timer(12).timeout
	var removed := not runtime.mobs.actors.has(id)
	var near := MobDomain._point(runtime.mobs.domain.states[id])+Vector3(0,5,3)
	runtime.player.inspect_at(near)
	await get_tree().create_timer(12).timeout
	var count := 0
	for child: Node in runtime.mobs.get_children():
		if child is MobActor and child.entity_id == id:
			count += 1
	result = {"id":id,"removed_far":removed,"restored_instances":count,"health":runtime.mobs.domain.states[id].health}
	print("P04_OFFSCREEN ",result)

func c02() -> void:
	result = {"running":true}
	var point := runtime.player.global_position+farm_offset
	var hit := runtime.terrain.surface_hit(point.x,point.z)
	if hit.is_empty():
		result = {"error":"no terrain"}
		return
	point = Vector3(floorf(point.x)+.5,hit.position.y+.02,floorf(point.z)+.5)
	var before := runtime.terrain.density_at(point)
	var error := runtime.session.edits.apply(point,.55,true,2)
	if error != OK:
		result = {"error":"terrain busy", "code":error}
		return
	var key := SurfaceLedger.cell_key(point)
	if not runtime.farms.plots.has(key):
		error = runtime.farms.till(point,true,1)
		runtime.farms.plant(key,runtime.player.inventory.state)
	runtime.farms.water(key,3)
	runtime.qa_advance(2)
	var outputs := runtime.farms.harvest(key)
	runtime.deliver(outputs,point)
	runtime.farms.plant(key,runtime.player.inventory.state)
	runtime.farms.water(key,3)
	runtime.qa_advance(1)
	var base := Vector3i(floori(point.x)+2,floori(point.y),floori(point.z))
	var ids: Array[String] = []
	var errors: Array = []
	for entry: Array in [["foundation",Vector3i.ZERO],["wall",Vector3i.ZERO],["ceiling",Vector3i(0,2,0)],["ceiling",Vector3i(1,0,0)],["pillar",Vector3i(1,0,0)]]:
		runtime.actions.selected_structure = entry[0]
		var prior: Array = runtime.building.pieces.keys()
		var placed := runtime.actions.build_at(base+Vector3i(entry[1]))
		errors.append(placed)
		for id: String in runtime.building.pieces:
			if id not in prior:
				ids.append(id)
	runtime.actions.selected_structure = "chest"
	errors.append(runtime.actions.build_at(base+Vector3i(0,0,2)))
	runtime.refresh(point)
	runtime.objects.reconcile()
	result = {"running":false,"plot":key,"crop_output":outputs,"density_unchanged":before == runtime.terrain.density_at(point),"placement_errors":errors,"structure_ids":ids,"containers":runtime.containers.records.size()}
	print("P04_QA_C02 ",result)

func open_chest() -> void:
	for id: String in runtime.containers.records:
		if runtime.containers.records[id].kind == "Chest":
			runtime.container_opened.emit(id)
			return

func break_plot() -> void:
	if runtime.farms.plots.is_empty():
		return
	var key: String = runtime.farms.plots.keys()[0]
	var row: Dictionary = runtime.farms.plots[key]
	var point := Vector3(row.position[0],row.position[1],row.position[2])
	var error := runtime.session.edits.apply(point,1.3,false)
	await get_tree().create_timer(1.5).timeout
	result = {"edit_error":error,"unsupported_plot_removed":not runtime.farms.plots.has(key),"key":key}
	print("P04_QA_SUPPORT_BREAK ",result)
