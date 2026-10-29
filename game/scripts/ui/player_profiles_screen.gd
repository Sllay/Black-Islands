extends FrontendPage

func _ready() -> void:
	frame("PERSONAGENS",Profiles.library.read("world",Profiles.world_slot).get("display_name","Mundo"))
	_refresh()
	action(footer,"Voltar",Flow.show_worlds,"Back")

func _refresh() -> void:
	for child: Node in content.get_children():
		content.remove_child(child)
		child.queue_free()
	for row: Dictionary in Profiles.library.summaries("player"):
		var panel := PanelContainer.new()
		content.add_child(panel)
		var body := HBoxContainer.new()
		body.add_theme_constant_override("separation",14)
		panel.add_child(body)
		if row.state == "empty":
			var text := ShellUI.label_text("Vazio • Crie seu personagem",22,ShellUI.GOLD)
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			body.add_child(text)
			action(body,"Criar",Flow.edit_player.bind(row.slot,false),"CreatePlayer%d"%row.slot)
			panel.custom_minimum_size.y = 80
			continue
		if row.state != "ready":
			body.add_child(ShellUI.label_text("Perfil indisponível • preservado",20))
			continue
		var portrait := LPCPortrait.new()
		portrait.present(row.data.appearance)
		body.add_child(portrait)
		var info := ShellUI.column(body,4)
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(ShellUI.label_text(row.data.name,24,ShellUI.GOLD))
		info.add_child(ShellUI.label_text("Level %d • %s" % [row.data.level,duration(row.data.played_seconds)],18))
		action(body,"Excluir",confirm_delete.bind("player",row.slot,_refresh),"DeletePlayer%d"%row.slot)
		action(body,"Editar",Flow.edit_player.bind(row.slot,true),"EditPlayer%d"%row.slot)
		action(body,"Jogar",_play.bind(row.slot),"PlayPlayer%d"%row.slot)

func _play(slot: int) -> void:
	Profiles.player_slot = slot
	Flow.enter_main()
