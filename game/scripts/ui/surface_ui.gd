class_name SurfaceUI
extends CanvasLayer
## Production action palette and dual-inventory view. Every mutation is intent.
var runtime: SurfaceRuntime
var panel: PanelContainer
var body: VBoxContainer
var opened_id := ""
var selection: Dictionary = {}
var quantity: SpinBox
var feedback: Label
var _grids: Array[GridContainer] = []

func _ready() -> void:
	layer = 8
	var safe := ShellSafeArea.new()
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(safe)
	var frame := MarginContainer.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_constant_override("margin_top",154)
	frame.add_theme_constant_override("margin_bottom",94)
	safe.add_child(frame)
	panel = PanelContainer.new()
	panel.theme = load("res://resources/ui/ShellTheme.tres")
	var background := StyleBoxFlat.new()
	background.bg_color = Color("132a32")
	background.set_corner_radius_all(12)
	panel.add_theme_stylebox_override("panel",background)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(panel)
	body = ShellUI.column(panel,8)
	body.add_theme_constant_override("margin_left",24)
	body.add_theme_constant_override("margin_top",24)
	panel.visible = false
	runtime.player.inventory.open_changed.connect(func(open: bool) -> void:
		if not open:
			panel.visible = false)
	runtime.container_opened.connect(open_container)
	_attach_button.call_deferred()

func _attach_button() -> void:
	var hud := runtime.get_tree().get_first_node_in_group("local_player").get_tree().root.find_child("ProductionHUD",true,false)
	if hud == null:
		return
	var button := ShellUI.button("Cultivar / Construir","SurfaceActions",Vector2(220,48))
	button.pressed.connect(open_palette)
	hud.find_child("ReturnToSaves",true,false).get_parent().add_child(button)

func _reset(title: String) -> void:
	for child: Node in body.get_children():
		body.remove_child(child)
		child.queue_free()
	_grids.clear()
	var header := HBoxContainer.new()
	body.add_child(header)
	header.add_child(ShellUI.label_text(title,26,ShellUI.GOLD))
	var close := ShellUI.button("Fechar","CloseSurface",Vector2(130,48))
	close.pressed.connect(func() -> void:
		panel.visible = false
		if runtime.player.inventory.is_open:
			runtime.player.inventory.toggle())
	header.add_child(close)
	if not runtime.player.inventory.is_open:
		runtime.player.inventory.toggle()
	panel.visible = true

func open_palette() -> void:
	_reset("OFICINA DE CAMPO")
	body.add_child(ShellUI.label_text("Escolha uma peça; mire com a câmera Build e toque em Attack.\nCultivo: enxada prepara, Interagir planta/colhe, regador molha.",20))
	var row := HBoxContainer.new()
	body.add_child(row)
	for entry: Array in [["foundation","Fundação"],["wall","Parede"],["ceiling","Plataforma"],["pillar","Pilar"],["chest","Baú"]]:
		var button := ShellUI.button(entry[1],entry[0],Vector2(160,64))
		button.pressed.connect(func() -> void:
			runtime.actions.selected_structure = entry[0]
			runtime.player.inventory.state.select_hotbar(3)
			if not runtime.player.camera_rig.build_mode:
				runtime.player.camera_rig.toggle_build()
			runtime.player.inventory.toggle()
			runtime.message.emit("Mire no solo/peça e toque Attack • "+str(entry[1])))
		row.add_child(button)
	var rotate := ShellUI.button("Girar encaixe da parede","RotateStructure",Vector2(250,56))
	rotate.pressed.connect(func() -> void: runtime.actions.rotation = (runtime.actions.rotation+1)%4)
	body.add_child(rotate)
	body.add_child(ShellUI.label_text("Peças de madeira: fundação 8 madeira + 2 pedra; parede 6 madeira; plataforma 4 madeira; pilar 6 madeira + 1 pedra; baú 8 madeira.",18,ShellUI.MUTED))
	var tools := HBoxContainer.new()
	body.add_child(tools)
	for entry: Array in [["Enxada",6],["Regador",7],["Machado",4],["Picareta",1]]:
		var button := ShellUI.button(entry[0],"SelectTool",Vector2(170,56))
		button.pressed.connect(func() -> void:
			runtime.player.inventory.state.select_hotbar(entry[1])
			runtime.player.inventory.toggle())
		tools.add_child(button)

func open_container(id: String) -> void:
	if not runtime.containers.inventories.has(id):
		return
	opened_id = id
	selection = {}
	var title: String = {"Chest":"Baú","WorldDropBag":"Pacote","DeathBagInventory":"Espólio","Corpse":"Corpo"}.get(runtime.containers.records[id].kind,"Container")
	_reset("BAGAGEM  ↔  "+title)
	var panes := HBoxContainer.new()
	panes.add_theme_constant_override("separation",24)
	body.add_child(panes)
	for store: InventoryState in [runtime.player.inventory.state,runtime.containers.inventories[id]]:
		var column := ShellUI.column(panes,8)
		column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		column.add_child(ShellUI.label_text("Sua bagagem" if store == runtime.player.inventory.state else "Container",20,ShellUI.GOLD))
		var grid := GridContainer.new()
		grid.columns = 5
		column.add_child(grid)
		_grids.append(grid)
		for index: int in InventoryState.CAPACITY:
			var button := ShellUI.button("—","Slot%d" % index,Vector2(90,52))
			button.pressed.connect(_select.bind(store,index))
			grid.add_child(button)
	var controls := HBoxContainer.new()
	body.add_child(controls)
	quantity = SpinBox.new()
	quantity.min_value = 1
	quantity.max_value = 999
	quantity.custom_minimum_size = Vector2(140,56)
	controls.add_child(quantity)
	for entry: Array in [["Transferir quantidade",false],["Transferir stack inteiro",true]]:
		var button := ShellUI.button(entry[0],"Transfer",Vector2(250,56))
		button.pressed.connect(_transfer.bind(entry[1]))
		controls.add_child(button)
	feedback = ShellUI.label_text("Escolha um stack de qualquer lado.",18,ShellUI.MUTED)
	body.add_child(feedback)
	_refresh()

func _select(source: InventoryState, index: int) -> void:
	var row := source.slot_at(index)
	if row.is_empty():
		return
	var other: InventoryState = runtime.containers.inventories[opened_id] if source == runtime.player.inventory.state else runtime.player.inventory.state
	selection = {"source":source,"target":other,"uid":row.stack_uid,"source_revision":source.revision,"target_revision":other.revision,"max":int(row.quantity)}
	quantity.max_value = row.quantity
	quantity.value = 1
	feedback.text = ItemCatalog.resolve(row.item_id).title+" • escolha a quantidade."

func _transfer(full: bool) -> void:
	if selection.is_empty():
		return
	var amount := int(selection.max) if full else int(quantity.value)
	var error := InventoryTransactions.transfer(selection.source,selection.target,selection.uid,amount,selection.source_revision,selection.target_revision)
	feedback.text = "Transferido." if error == OK else "Inventário mudou ou não há espaço. Selecione novamente."
	selection = {}
	_refresh()

func _refresh() -> void:
	var stores: Array[InventoryState] = [runtime.player.inventory.state,runtime.containers.inventories[opened_id]]
	for pane: int in range(2):
		for index: int in InventoryState.CAPACITY:
			var row := stores[pane].slot_at(index)
			var button: Button = _grids[pane].get_child(index)
			button.text = "—" if row.is_empty() else "%s %d" % [ItemCatalog.resolve(row.item_id).icon,row.quantity]
