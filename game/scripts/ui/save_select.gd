extends Control

var status_label: Label

func _ready() -> void:
	print("FLOW SaveSelect")
	ShellUI.setup(self)
	var safe := ShellSafeArea.new()
	safe.name = "SafeArea"
	add_child(safe)
	var center := CenterContainer.new()
	center.name = "Center"
	safe.add_child(center)
	var content := ShellUI.column(center, 16)
	content.name = "Content"
	content.add_child(ShellUI.label_text("B L A C K   I S L A N D", 40))
	content.add_child(ShellUI.label_text("Escolha sua jornada", 24, ShellUI.GOLD))
	var grid := GridContainer.new()
	grid.name = "Slots"
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	content.add_child(grid)
	var summaries := Profiles.summaries()
	for index: int in range(summaries.size()):
		var card := SaveSlotCard.new()
		card.configure(summaries[index], index)
		card.chosen.connect(_on_slot_chosen)
		grid.add_child(card)
	status_label = ShellUI.label_text("Quatro jornadas. Infinitas histórias.", 18, ShellUI.MUTED)
	content.add_child(status_label)

func _on_slot_chosen(slot_id: String) -> void:
	var error := Profiles.select_slot(slot_id)
	if error == OK:
		Flow.enter_main()
	else:
		status_label.text = "Não foi possível salvar. Seus dados foram preservados."
