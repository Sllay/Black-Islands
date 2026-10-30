class_name SurfaceUI
extends CanvasLayer
## Production action palette and dual-inventory view. Every mutation is intent.
var runtime: SurfaceRuntime
var panel: PanelContainer
var body: VBoxContainer

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
	var inventory := get_tree().root.find_child("InventoryPanel",true,false) as PlayerInventoryPanel
	if inventory != null:
		inventory.visible = false
	panel.visible = true

func open_palette() -> void:
	_reset("OFICINA DE CAMPO")
	body.add_child(ShellUI.label_text("Escolha uma peça; mire com a câmera Build e toque em Attack.\nCultivo: enxada prepara, Interagir planta/colhe, regador molha.",20))
	var row := HBoxContainer.new()
	body.add_child(row)
	for entry: Array in [["foundation","Fundação"],["wall","Parede"],["ceiling","Plataforma"],["pillar","Pilar"],["chest","Baú"],["workbench","Bancada"]]:
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
	var inventory := get_tree().root.find_child("InventoryPanel",true,false) as PlayerInventoryPanel
	if inventory != null:
		panel.visible = false
		inventory.open_container(id)
