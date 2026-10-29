extends FrontendPage
var staged: Dictionary
var audio_page: VBoxContainer
var graphics_page: VBoxContainer
var values: Dictionary = {}

func _ready() -> void:
	staged = GameSettings.current.duplicate(true)
	frame("OPTIONS","Ajuste sua experiência")
	var tabs := HBoxContainer.new()
	content.add_child(tabs)
	var group := ButtonGroup.new()
	for entry: Array in [["Áudio",0],["Gráfico",1],["Outros",2]]:
		var button := action(tabs,entry[0],_tab.bind(entry[1]),"Tab%d"%entry[1],entry[1] == 2)
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = entry[1] == 0
	audio_page = ShellUI.column(content,16)
	for bus: String in ["Music","Audio","Voice"]:
		_slider(audio_page,{"Music":"Music • Música","Audio":"Audio • Sons do jogo","Voice":"Voice • Vocalizações"}[bus],int(staged.audio[bus]),0,100,
			func(value: int) -> void: staged.audio[bus] = value,bus)
	graphics_page = ShellUI.column(content,12)
	graphics_page.visible = false
	graphics_page.add_child(ShellUI.label_text("Modo gráfico",22,ShellUI.GOLD))
	var presets := HBoxContainer.new()
	graphics_page.add_child(presets)
	var preset_group := ButtonGroup.new()
	for quality: String in GameSettings.catalog.presets:
		var button := action(presets,quality,func() -> void: staged.quality = quality,"Quality"+quality)
		button.toggle_mode = true
		button.button_group = preset_group
		button.button_pressed = quality == staged.quality
	_slider(graphics_page,"Distância do mundo",int(staged.distance),2,10,func(value: int) -> void: staged.distance = value,"Distance")
	for key: String in ["shadows","vsync"]:
		var toggle := CheckButton.new()
		toggle.text = "Shadows" if key == "shadows" else "VSync"
		toggle.button_pressed = staged[key]
		toggle.custom_minimum_size.y = 48
		toggle.toggled.connect(func(enabled: bool) -> void: staged[key] = enabled)
		graphics_page.add_child(toggle)
	var backends := OptionButton.new()
	backends.name = "Backend"
	backends.custom_minimum_size.y = 48
	for backend: String in GameSettings.catalog.backends:
		backends.add_item(backend.replace("_"," ").capitalize())
		backends.set_item_metadata(backends.item_count-1,backend)
		if backend == staged.backend:
			backends.select(backends.item_count-1)
	backends.item_selected.connect(func(index: int) -> void: staged.backend = backends.get_item_metadata(index))
	graphics_page.add_child(backends)
	graphics_page.add_child(ShellUI.label_text("Renderer: seleção para próxima inicialização/export.\nA distância é um nível de orçamento; não uma contagem de chunks.",16,ShellUI.MUTED))
	action(footer,"Cancelar",Flow.show_menu,"Cancel")
	action(footer,"Salvar e sair",_save,"SaveOptions")

func _slider(parent: Node, title: String, value: int, minimum: int, maximum: int, changed: Callable, id: String) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := ShellUI.label_text(title,20)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var amount := ShellUI.label_text(str(value),20,ShellUI.GOLD)
	amount.custom_minimum_size.x = 50
	row.add_child(amount)
	var slider := HSlider.new()
	slider.name = id
	slider.min_value = minimum
	slider.max_value = maximum
	slider.step = 1
	slider.value = value
	slider.custom_minimum_size.y = 44
	slider.value_changed.connect(func(next: float) -> void:
		amount.text = str(int(next))
		changed.call(int(next)))
	parent.add_child(slider)
	values[id] = slider

func _tab(index: int) -> void:
	audio_page.visible = index == 0
	graphics_page.visible = index == 1

func _save() -> void:
	if GameSettings.save(staged) == OK:
		Flow.show_menu()
	else:
		notice.text = "Não foi possível salvar. As alterações continuam pendentes."
