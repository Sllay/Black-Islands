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
	hud = load("res://scenes/ui/ProductionHUD.tscn").instantiate()
	add_child(hud)
	hud.present_world()
	panel = hud.find_child("InventoryPanel",true,false)
	panel.controller.registry = registry
	actor.inventory.toggle()
	panel.open_container("qa.chest")
	print("R3_INVENTORY_UX_READY")
func report() -> Dictionary:
	return {"player":actor.inventory.state.snapshot(),"chest":registry.inventories["qa.chest"].snapshot(),"dragging":panel.gestures.dragging,"popup":panel._popup.get_class() if is_instance_valid(panel._popup) else "","bag_count":registry.records.size()-1}
func touch_slot(side: String, index: int, pressed: bool) -> void:
	var slot: InventorySlotView = panel.find_child(side+"Slot%02d"%index,true,false)
	if slot == null:
		return
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = slot.get_global_rect().get_center()
	event.pressed = pressed
	Input.parse_input_event(event)
func drag_to(side: String, index: int) -> void:
	var slot: InventorySlotView = panel.find_child(side+"Slot%02d"%index,true,false)
	var event := InputEventScreenDrag.new()
	event.index = 0
	event.position = slot.get_global_rect().get_center()
	Input.parse_input_event(event)
func cancel_popup() -> void:
	panel._close_popup()
