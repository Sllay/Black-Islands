extends FrontendPage
var title_field: LineEdit
var config: Dictionary
var portrait: LPCPortrait
var choices: VBoxContainer

func _ready() -> void:
	var prior := Profiles.library.read("player",Flow.edit_slot) if Flow.edit_existing else {}
	config = prior.get("appearance",LPCCustomization.default_for("male")).duplicate(true)
	frame("ROUPAS E COSMÉTICOS" if Flow.edit_existing else "CRIAR PERSONAGEM")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",32)
	content.add_child(row)
	portrait = LPCPortrait.new()
	portrait.custom_minimum_size = Vector2(240,300)
	row.add_child(portrait)
	choices = ShellUI.column(row,10)
	choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_field = field(choices,"Nome",prior.get("name","Viajante_%03d"%randi_range(0,999)),"PlayerName")
	title_field.max_length = 32
	title_field.editable = not Flow.edit_existing
	var body := OptionButton.new()
	body.name = "Presentation"
	body.custom_minimum_size.y = 48
	for kind: String in LPCCustomization.body_types():
		body.add_item("Masculina" if kind == "male" else "Feminina")
		body.set_item_metadata(body.item_count-1,kind)
		if kind == config.body_type:
			body.select(body.item_count-1)
	body.disabled = Flow.edit_existing
	body.item_selected.connect(func(index: int) -> void:
		config = LPCCustomization.default_for(body.get_item_metadata(index))
		_rebuild_choices())
	choices.add_child(body)
	_rebuild_choices()
	action(footer,"Voltar",Flow.show_players,"Back")
	action(footer,"Salvar" if Flow.edit_existing else "Criar",_save,"ConfirmPlayer")

func _rebuild_choices() -> void:
	for child: Node in choices.get_children():
		if child.has_meta("catalog_choice"):
			choices.remove_child(child)
			child.queue_free()
	for role: String in LPCCustomization.roles():
		var rows := LPCCustomization.options(role,str(config.body_type),str(config.palettes.get("body","")))
		if rows.is_empty():
			continue
		var row := HBoxContainer.new()
		row.set_meta("catalog_choice",true)
		choices.add_child(row)
		var title := ShellUI.label_text({"body":"Corpo / pele","head":"Rosto","ears":"Orelhas","eyes":"Olhos","hair":"Cabelo / cor","torso":"Roupa","legs":"Calça"}.get(role,role.capitalize()),18)
		title.custom_minimum_size.x = 180
		row.add_child(title)
		var option := OptionButton.new()
		option.name = "Choice"+role.capitalize()
		option.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		option.custom_minimum_size.y = 48
		option.disabled = Flow.edit_existing and role in LPCCustomization.immutable_roles()
		for entry: Dictionary in rows:
			option.add_item(str(entry.get("title",entry.id.trim_prefix("lpc.").replace("_"," "))))
			option.set_item_metadata(option.item_count-1,entry.id)
			if entry.id == config.selections.get(role):
				option.select(option.item_count-1)
		option.item_selected.connect(func(index: int) -> void:
			config = LPCCustomization.select(config,role,option.get_item_metadata(index))
			_rebuild_choices())
		row.add_child(option)
	portrait.present(config)
	portrait.custom_minimum_size = Vector2(240,300)

func _save() -> void:
	var error := Profiles.library.edit_player(Flow.edit_slot,config) if Flow.edit_existing else Profiles.library.create_player(Flow.edit_slot,title_field.text,config)
	if error == OK:
		Profiles.player_slot = Flow.edit_slot
		Flow.show_players()
	else:
		notice.text = "Revise nome e aparência. Características de identidade não podem ser editadas."
