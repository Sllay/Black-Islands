extends Control
## Lightweight production HUD/panel fixture. No voxel benchmark in inventory QA.
var actor: PlayerActor
var hud: Control
var panel: PlayerInventoryPanel
var registry := ContainerService.new()
func _ready() -> void:
	Engine.max_fps = 60
	_setup.call_deferred()
func _setup() -> void:
	ShellUI.setup(self)
	actor = load("res://scenes/player/Player.tscn").instantiate()
	add_child(actor)
	actor.set_physics_process(false)
	actor.position = Vector3.ZERO
	var empty := InventoryState.new()
	empty.inventory_id = actor.inventory.state.inventory_id
	InventoryTransactions.commit([actor.inventory.state],[empty],[actor.inventory.state.revision])
	actor.inventory.state.add_item("bi.resource.meat",11)
	actor.inventory.state.add_item("bi.food.coconut",20,{"spoilage":{"remaining":36}})
	actor.inventory.state.add_item("bi.weapon.starter_sword",1)
	actor.inventory.state.add_item("bi.resource.wood",50)
	actor.inventory.state.assign_hotbar(0,2)
	actor.inventory.state.assign_hotbar(1,1)
	var chest := registry.create("qa.chest",Vector3(1,0,0))
	chest.add_item("bi.food.coconut",30,{"spoilage":{"remaining":30}})
	chest.add_item("bi.resource.stone",200)
	actor.inventory.simulation.bind_world(registry,func(_store: InventoryState) -> Vector3: return Vector3.ZERO,Callable())
	actor.inventory.crafting.bind_world(registry,"qa.world")
	hud = load("res://scenes/ui/ProductionHUD.tscn").instantiate()
	add_child(hud)
	hud.present_world()
	panel = hud.find_child("InventoryPanel",true,false)
	panel.controller.registry = registry
	actor.inventory.toggle()
	panel.open_container("qa.chest")
	print("R3_INVENTORY_UX_READY")
	if "--auto" in OS.get_cmdline_user_args():
		run_automated()
func report() -> Dictionary:
	return {"player":actor.inventory.state.snapshot(),"chest":registry.inventories["qa.chest"].snapshot(),"dragging":panel.gestures.dragging,"popup":panel._popup.get_class() if is_instance_valid(panel._popup) else "","bag_count":registry.records.size()-1}
func touch_slot(side: String, index: int, pressed: bool) -> void:
	var slot: InventorySlotView = panel.cells[20+index] if side == "Hotbar" else panel.find_child(side+"Slot%02d"%index,true,false)
	if slot == null:
		return
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = slot.get_global_rect().get_center()
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func drag_to(side: String, index: int) -> void:
	var slot: InventorySlotView = panel.cells[20+index] if side == "Hotbar" else panel.find_child(side+"Slot%02d"%index,true,false)
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = slot.get_global_rect().get_center()
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func cancel_popup() -> void:
	panel._close_popup()

var failures := 0
var assertions := 0
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("R3_INVENTORY_UX "+label)
func pause(seconds: float = .05) -> void:
	await get_tree().create_timer(seconds).timeout
func tap_slot(side: String, index: int) -> void:
	touch_slot(side,index,true)
	await pause()
	touch_slot(side,index,false)
	await pause()
func drag_slot(side: String, index: int, destination: String, target: int) -> void:
	touch_slot(side,index,true)
	await pause(.48)
	check(panel.gestures.dragging,"long press begins drag")
	drag_to(destination,target)
	touch_slot(destination,target,false)
	await pause()
func run_automated() -> void:
	await pause(.2)
	actor.inventory.simulation.set_process(false)
	var state := actor.inventory.state
	check(panel.paired != null and panel.cells.size() == 53,"dual inventory20+20 hotbar8 gear5")
	await tap_slot("Player",0)
	await pause(.35)
	check(panel._popup is InventoryItemPopup,"single tap details")
	check(panel._popup != null and panel._popup.find_child("consume",true,false) == null,"resource has no consume action")
	cancel_popup()
	await pause()
	await tap_slot("Player",1)
	await tap_slot("Player",1)
	await pause()
	check(state.slot_at(1).is_empty() and registry.inventories["qa.chest"].slot_at(0).quantity == 32,"double tap maximum transfer")
	check(registry.inventories["qa.chest"].slot_at(2).quantity == 18,"double tap remainder creates another stack")
	await tap_slot("Container",2)
	await tap_slot("Container",2)
	await pause()
	check(state.slot_at(1).quantity == 18,"reverse double tap")
	await drag_slot("Player",0,"Player",7)
	check(state.slot_at(0).is_empty() and state.slot_at(7).quantity == 11,"same inventory move")
	await drag_slot("Player",7,"Player",3)
	check(state.slot_at(7).item_id == "bi.resource.wood" and state.slot_at(3).item_id == "bi.resource.meat","same inventory swap")
	await drag_slot("Player",2,"Hotbar",4)
	check(state.hotbar_at(4).stack_uid == state.slot_at(2).stack_uid,"hotbar assigns reference")
	await drag_slot("Player",7,"Hotbar",5)
	check(state.hotbar_at(5).is_empty(),"resource hotbar rejection")
	await drag_slot("Player",3,"Container",3)
	check(panel._popup is InventoryQuantityModal,"cross inventory modal before mutation")
	var modal := panel._popup as InventoryQuantityModal
	check(modal.source_title == "Sua bagagem" and modal.target_title == "Container" and modal.slider.step == 1,"source destination integer slider")
	modal._sync(4)
	modal.confirmed.emit(modal.amount)
	await pause()
	check(state.slot_at(3).quantity == 7 and registry.inventories["qa.chest"].slot_at(2).quantity == 4,"confirmed partial transfer")
	for mode: String in ["one","half","all"]:
		var split_uid: String = state.slot_at(3).stack_uid
		check(panel.controller.split(state,split_uid,mode,state.revision) == OK,"split "+mode)
	check(is_equal_approx(StackPolicy.freshness(state.slot_at(0),state.time_source.now),StackPolicy.freshness(state.slot_at(3),state.time_source.now)),"split copies freshness")
	var uid: String = state.slot_at(1).stack_uid
	check(panel.controller.reorganize(state,uid,0,state.revision) == OK,"different item swap via intent")
	var dst := InventoryState.new()
	dst.inventory_id = "qa.merge"
	dst.time_source = state.time_source
	dst.add_item("bi.food.coconut",30,{"spoilage":{"remaining":30}})
	var plan := InventoryCommands.transfer_plan(state,dst,uid,18,state.revision,dst.revision,true)
	check(plan.commit() == OK and dst.slot_at(0).quantity == 32,"partial merge service")
	check(is_equal_approx(StackPolicy.freshness(dst.slot_at(0),dst.time_source.now),.1),"merge destination freshness")
	actor.inventory.toggle()
	actor.inventory.toggle()
	await pause()
	check(panel.paired == null and panel.find_child("ContainerGrid",true,false) == null,"reopen clears old context")
	print("R3_INVENTORY_UX ","PASS" if failures == 0 else "FAIL"," assertions=",assertions," failures=",failures)
	get_tree().quit(1 if failures else 0)

func qa_workbench() -> void:
	var bench := registry.create("qa.bench",Vector3(1,0,0),"Workbench")
	bench.add_item("bi.resource.wood",64)
	bench.add_item("bi.resource.stone",32)
	panel.open_container("qa.bench")
