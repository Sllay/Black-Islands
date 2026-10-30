class_name PlayerInventoryPanel
extends Control
## One event-driven screen for player/container/equipment/hotbar; UI emits intent.
var component: InventoryComponent
var controller := InventoryIntentController.new()
var gestures: InventoryGestureController
var paired: InventoryState
var opened_id := ""
var cells: Array[InventorySlotView] = []
var feedback: Label
var craft_host: VBoxContainer
var _bag_host: HBoxContainer
var _right: VBoxContainer
var _context: Label
var _fresh: Timer
var _popup: Control
var _ghost: PanelContainer
var _ghost_label: Label
var _watched: Array[InventoryState] = []
var _built := false
var _mode := "container"
func configure(owner_component: InventoryComponent) -> void:
	component = owner_component
	controller.configure(component)
	component.open_changed.connect(_open_changed)
func _ready() -> void:
	name = "InventoryPanel"
	z_index = 20
	ShellUI.setup(self)
	get_node("Background").offset_top = clampf(get_viewport_rect().size.y*.20,100,154)
	mouse_filter = Control.MOUSE_FILTER_STOP
	gestures = InventoryGestureController.new()
	add_child(gestures)
	gestures.tap.connect(_tap)
	gestures.double_tap.connect(_quick_transfer)
	gestures.dropped.connect(_drop_intent)
	gestures.drag_visual.connect(_drag_visual)
	gestures.drag_finished.connect(_clear_ghost)
	controller.feedback.connect(_message)
	var safe := ShellSafeArea.new()
	add_child(safe)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top",clampi(roundi(get_viewport_rect().size.y*.20),100,154))
	margin.add_theme_constant_override("margin_bottom",18)
	safe.add_child(margin)
	var content := ShellUI.column(margin,8)
	var header := HBoxContainer.new()
	content.add_child(header)
	_context = ShellUI.label_text("BAGAGEM",24,ShellUI.GOLD)
	_context.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_context)
	for entry: Array in [["Inventário","container"],["Criação","craft"]]:
		var button := ShellUI.button(entry[0],"Tab_"+entry[1],Vector2(140,46))
		button.pressed.connect(func() -> void:
			_mode = entry[1]
			_build_panes())
		header.add_child(button)
	var organize := ShellUI.button("Organizar","Organize",Vector2(140,46))
	organize.pressed.connect(func() -> void: _result(controller.organize()))
	header.add_child(organize)
	var close := ShellUI.button("Fechar","CloseInventory",Vector2(120,46))
	close.pressed.connect(component.toggle)
	header.add_child(close)
	_bag_host = HBoxContainer.new()
	_bag_host.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_bag_host.add_theme_constant_override("separation",16)
	content.add_child(_bag_host)
	feedback = ShellUI.label_text("Toque para detalhes • segure para mover",16,ShellUI.MUTED)
	content.add_child(feedback)
	_fresh = Timer.new()
	_fresh.wait_time = float(gestures.tuning.freshness_refresh_seconds)
	_fresh.timeout.connect(func() -> void:
		for cell: InventorySlotView in cells:
			if is_instance_valid(cell):
				cell.update_freshness())
	add_child(_fresh)
	var runtime := get_tree().get_first_node_in_group("surface_runtime") as SurfaceRuntime
	if runtime != null:
		controller.registry = runtime.containers
		runtime.container_opened.connect(open_container)
	_built = true
	_watch(component.state)
	_build_panes()
	_open_changed(component.is_open)
func _watch(store: InventoryState) -> void:
	if not _watched.has(store):
		_watched.append(store)
		store.changed.connect(_changed)
func _changed(_revision: int) -> void:
	if visible:
		for cell: InventorySlotView in cells:
			if is_instance_valid(cell):
				cell.refresh()
func _build_panes() -> void:
	if not _built:
		return
	gestures.cancel()
	for child: Node in _bag_host.get_children():
		_bag_host.remove_child(child)
		child.queue_free()
	cells.clear()
	gestures.slots.clear()
	var left := ShellUI.column(_bag_host,8)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid(left,component.state,"SUA BAGAGEM","Player")
	var hotbar := HBoxContainer.new()
	hotbar.add_theme_constant_override("separation",3)
	left.add_child(hotbar)
	for index: int in InventoryState.HOTBAR_SIZE:
		_slot(hotbar,component.state,index,"hotbar")
	var gear := ShellUI.column(_bag_host,6)
	gear.custom_minimum_size.x = 140
	gear.add_child(ShellUI.label_text("EQUIPAMENTO",16,ShellUI.GOLD))
	for key: String in InventoryState.EQUIPMENT:
		var slot := _slot(gear,component.state,0,"equipment")
		slot.equipment_key = key
		slot.refresh()
	_right = ShellUI.column(_bag_host,8)
	_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	craft_host = _right
	if paired != null and _mode == "container":
		_grid(_right,paired,"CONTAINER","Container")
		_context.text = "BAGAGEM  ↔  CONTAINER"
	else:
		_context.text = "BAGAGEM"
		_install_craft()
	_changed(0)
func _install_craft() -> void:
	# The craft view is installed by the crafting domain integration checkpoint.
	_right.add_child(ShellUI.label_text("CRIAÇÃO",22,ShellUI.GOLD))
func _grid(parent: Node, store: InventoryState, title: String, prefix: String) -> void:
	parent.add_child(ShellUI.label_text(title,18,ShellUI.GOLD))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(scroll)
	var grid := GridContainer.new()
	grid.name = prefix+"Grid"
	grid.columns = 5
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation",6)
	grid.add_theme_constant_override("v_separation",6)
	scroll.add_child(grid)
	for index: int in InventoryState.CAPACITY:
		var slot := _slot(grid,store,index)
		slot.name = prefix+"Slot%02d"%index
func _slot(parent: Node, store: InventoryState, index: int, kind: String = "inventory") -> InventorySlotView:
	var slot := InventorySlotView.new()
	slot.store = store
	slot.index = index
	slot.kind = kind
	slot.gestures = gestures
	slot.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(slot)
	if kind == "hotbar":
		slot.custom_minimum_size = Vector2(44,52)
	cells.append(slot)
	gestures.slots.append(slot)
	return slot
func open_container(id: String) -> void:
	if controller.registry == null or not controller.registry.inventories.has(id):
		return
	opened_id = id
	paired = controller.registry.inventories[id]
	controller.paired = paired
	if not controller.allowed(paired):
		paired = null
		controller.paired = null
		return
	_watch(paired)
	_mode = "container"
	if not component.is_open:
		component.toggle()
	_build_panes()
func _open_changed(open: bool) -> void:
	visible = open
	if gestures != null:
		gestures.enabled = open
	if not _built:
		return
	for key: String in ["Movement","Hotbar","Actions"]:
		var control := get_parent().find_child(key,true,false) as CanvasItem
		if control != null:
			control.visible = not open
	if open:
		_build_panes()
		_fresh.start()
		_changed(0)
	else:
		_fresh.stop()
		gestures.cancel()
		_close_popup()
		paired = null
		controller.paired = null
		opened_id = ""
func _tap(slot: InventorySlotView) -> void:
	if slot.row.is_empty():
		return
	_close_popup()
	var row := slot.row.duplicate(true)
	var revision := slot.store.revision
	var popup := InventoryItemPopup.new()
	popup.row = row
	popup.freshness = StackPolicy.freshness(row,slot.store.time_source.now)
	var free := slot.store._slots.has(null)
	var definition := ItemCatalog.resolve(row.item_id)
	popup.actions = {"consume":controller.can_consume(row),"drop":definition.droppable and component.simulation.drops != null,"split":row.quantity > 1 and free,"unassign":slot.kind == "hotbar","unequip":slot.kind == "equipment"}
	popup.action.connect(func(key: String) -> void:
		_close_popup()
		if key.begins_with("split_"):
			_result(controller.split(slot.store,row.stack_uid,key.trim_prefix("split_"),revision))
		elif key == "consume":
			_result(controller.consume(slot.store,row.stack_uid,revision))
		elif key == "drop":
			_quantity(slot.store,null,row,revision,0,true)
		elif key in ["unassign","unequip"]:
			_result(controller.unassign(slot.store,slot.index,slot.equipment_key if key == "unequip" else "",revision)))
	popup.dismissed.connect(_close_popup)
	add_child(popup)
	_popup = popup
	gestures.enabled = false
func _quick_transfer(slot: InventorySlotView) -> void:
	if slot.row.is_empty() or paired == null:
		_tap(slot)
		return
	var target := paired if slot.store == component.state else component.state
	controller.transfer(slot.store,target,slot.row.stack_uid,int(slot.row.quantity),slot.store.revision,target.revision,true)
func _drop_intent(payload: Dictionary, target: InventorySlotView) -> void:
	var source: InventoryState = payload.store
	if target.kind in ["hotbar","equipment"]:
		if source != component.state or source.revision != payload.revision:
			_message("Transfira primeiro para sua bagagem.")
			return
		_result(controller.assign(source,payload.uid,target.index,target.equipment_key if target.kind == "equipment" else "",int(payload.revision)))
	elif target.store == source:
		_result(controller.reorganize(source,payload.uid,target.index,int(payload.revision)))
	else:
		var row := source.record_by_uid(payload.uid)
		if not row.is_empty():
			_quantity(source,target.store,row,int(payload.revision),target.store.revision)
func _quantity(source: InventoryState, target: InventoryState, row: Dictionary, source_revision: int, target_revision: int, drop: bool = false) -> void:
	var maximum := int(row.quantity) if drop else InventoryCommands.transferable(source,target,row.stack_uid)
	if maximum < 1:
		_message("Destino cheio.")
		return
	var modal := InventoryQuantityModal.new()
	modal.item_title = ItemCatalog.resolve(row.item_id).title
	modal.source_title = "Sua bagagem" if source == component.state else "Container"
	modal.target_title = "Mundo" if drop else ("Sua bagagem" if target == component.state else "Container")
	modal.source_quantity = int(row.quantity)
	modal.maximum = maximum
	modal.cancelled.connect(_close_popup)
	modal.confirmed.connect(func(quantity: int) -> void:
		_close_popup()
		if drop:
			_result(controller.drop(source,row.stack_uid,quantity,source_revision))
		else:
			controller.transfer(source,target,row.stack_uid,quantity,source_revision,target_revision))
	add_child(modal)
	_popup = modal
	gestures.enabled = false
func _drag_visual(point: Vector2, row: Dictionary) -> void:
	if _ghost == null:
		_ghost = PanelContainer.new()
		_ghost.z_index = 100
		_ghost.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ghost_label = ShellUI.label_text("",24,ShellUI.GOLD)
		_ghost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_ghost.add_child(_ghost_label)
		add_child(_ghost)
	_ghost_label.text = "%s ×%d"%[ItemCatalog.resolve(row.item_id).icon,row.quantity]
	_ghost.position = point+Vector2(12,-46)
func _clear_ghost() -> void:
	if is_instance_valid(_ghost):
		_ghost.queue_free()
	_ghost = null
func _close_popup() -> void:
	if is_instance_valid(_popup):
		_popup.queue_free()
	_popup = null
	if gestures != null:
		gestures.enabled = visible
func _message(text: String) -> void:
	if feedback != null:
		feedback.text = text
func _result(error: Error) -> void:
	_message("Atualizado." if error == OK else "Ação indisponível ou inventário alterado.")
func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		if _popup != null:
			_close_popup()
		else:
			component.toggle()
		get_viewport().set_input_as_handled()
