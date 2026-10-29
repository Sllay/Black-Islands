extends FrontendPage

func _ready() -> void:
	frame("B L A C K   I S L A N D","Uma ilha. Muitas histórias.")
	var center := CenterContainer.new()
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	content.add_child(center)
	var column := ShellUI.column(center,16)
	column.add_child(ShellUI.label_text("Sua próxima jornada",28))
	for entry: Array in [["Play",Flow.show_worlds,false],["Multiplayer",func() -> void: pass,true],["Options",Flow.show_options,false],["Quit",Flow.request_quit,false]]:
		var button := action(column,entry[0],entry[1],entry[0],entry[2])
		button.custom_minimum_size = Vector2(360,64)
	footer.add_child(ShellUI.label_text("CHAPTER 1",18,ShellUI.MUTED))
