extends Control

func _ready() -> void:
	print("FLOW SaveSelect")
	ShellUI.setup(self)
	var safe := ShellSafeArea.new()
	add_child(safe)
	var center := CenterContainer.new()
	safe.add_child(center)
	var content := ShellUI.column(center, 20)
	content.add_child(ShellUI.label_text("B L A C K   I S L A N D", 40))
	content.add_child(ShellUI.label_text("Escolha sua jornada", 24, ShellUI.GOLD))
	for index: int in range(4):
		var slot := ShellUI.button("Jornada %02d" % (index + 1), "Slot%02d" % (index + 1), Vector2(640, 64))
		slot.disabled = true
		content.add_child(slot)
