extends FrontendPage

func _ready() -> void:
	frame("MUNDOS","Escolha onde sua história continua")
	_refresh()
	action(footer,"Voltar",Flow.show_menu,"Back")

func _refresh() -> void:
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
	for row: Dictionary in Profiles.library.summaries("world"):
		var panel := PanelContainer.new()
		panel.custom_minimum_size.y = 92
		content.add_child(panel)
		var body := HBoxContainer.new()
		body.add_theme_constant_override("separation",14)
		panel.add_child(body)
		if row.state == "empty":
			var text := ShellUI.column(body,2)
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text.add_child(ShellUI.label_text("Vazio",24,ShellUI.GOLD))
			text.add_child(ShellUI.label_text("Clique para criar o mundo",18,ShellUI.MUTED))
			action(body,"Criar",Flow.edit_world.bind(row.slot,false),"CreateWorld%d"%row.slot)
			continue
		if row.state != "ready":
			body.add_child(ShellUI.label_text("Dados indisponíveis • preservados",20))
			continue
		var preview := TextureRect.new()
		preview.custom_minimum_size = Vector2(144,81)
		preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var path := Profiles.library.world_directory(row.data).path_join("preview.jpg")
		if FileAccess.file_exists(path):
			var image := Image.load_from_file(path)
			if image != null:
				preview.texture = ImageTexture.create_from_image(image)
		body.add_child(preview)
		var info := ShellUI.column(body,2)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var title := ShellUI.label_text(row.data.display_name,24,ShellUI.GOLD)
		title.clip_text = true
		title.tooltip_text = row.data.display_name
		info.add_child(title)
		info.add_child(ShellUI.label_text("%s  •  %s  •  Dia %d" % [row.data.difficulty,duration(row.data.played_seconds),1+int(row.data.world_clock/SurfaceLedger.DAY)],18))
		action(body,"Excluir",confirm_delete.bind("world",row.slot,_refresh),"DeleteWorld%d"%row.slot)
		action(body,"Editar",Flow.edit_world.bind(row.slot,true),"EditWorld%d"%row.slot)
		action(body,"Jogar",_play.bind(row.slot),"PlayWorld%d"%row.slot)

func _play(slot: int) -> void:
	Profiles.world_slot = slot
	Flow.show_players()
