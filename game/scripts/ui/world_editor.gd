extends FrontendPage
var title_field: LineEdit
var seed_field: LineEdit

func _ready() -> void:
	var prior := Profiles.library.read("world",Flow.edit_slot) if Flow.edit_existing else {}
	frame("EDITAR MUNDO" if Flow.edit_existing else "CRIAR MUNDO")
	title_field = field(content,"Nome",prior.get("display_name","Mundo_%03d"%randi_range(0,999)),"WorldName")
	title_field.max_length = 48
	seed_field = field(content,"Seed",str(prior.get("world_seed",randi_range(1,2147483646))),"WorldSeed")
	seed_field.editable = not prior.get("generated",false)
	if not seed_field.editable:
		content.add_child(ShellUI.label_text("Seed bloqueada: este mundo já foi gerado.",16,ShellUI.MUTED))
	content.add_child(ShellUI.label_text("Dificuldade",20,ShellUI.GOLD))
	var difficulties := HBoxContainer.new()
	content.add_child(difficulties)
	var group := ButtonGroup.new()
	for label: String in ["Normal","Difícil","Extremo"]:
		var button := action(difficulties,label,func() -> void: pass,"Difficulty"+label,label != "Normal")
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = label == "Normal"
	action(footer,"Voltar",Flow.show_worlds,"Back")
	action(footer,"Salvar" if Flow.edit_existing else "Criar",_save,"ConfirmWorld")

func _save() -> void:
	if not seed_field.text.is_valid_int() or absf(float(seed_field.text)) > 2147483647:
		notice.text = "Use uma seed inteira de 32 bits."
		return
	var error := Profiles.library.edit_world(Flow.edit_slot,title_field.text,int(seed_field.text)) if Flow.edit_existing else Profiles.library.create_world(Flow.edit_slot,title_field.text,int(seed_field.text))
	if error != OK:
		notice.text = "Não foi possível salvar este mundo. Revise o nome/seed."
		return
	Profiles.world_slot = Flow.edit_slot
	if Flow.edit_existing:
		Flow.show_worlds()
	else:
		Flow.show_players()
