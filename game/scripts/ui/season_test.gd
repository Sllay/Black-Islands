extends Control
## Explicit QA entrypoint. Its profile namespace never targets production saves.

var safe: ShellSafeArea
var information: Label
var controls: VBoxContainer
var confirmation: CheckButton

func _ready() -> void:
	Profiles.use_test_profiles()
	ShellUI.setup(self)
	safe = ShellSafeArea.new()
	safe.name = "SafeArea"
	add_child(safe)
	var body := ShellUI.column(safe, 16)
	var toggle := ShellUI.button("SEASON TEST / P04  •  recolher / expandir", "ToggleQA")
	toggle.pressed.connect(func() -> void: controls.visible = not controls.visible)
	body.add_child(toggle)
	controls = ShellUI.column(body, 12)
	information = ShellUI.label_text("", 20, ShellUI.GOLD)
	controls.add_child(information)
	controls.add_child(ShellUI.label_text("P04: entre na ilha • F2 abre QA integrado de cultivo, construção, fauna, corpos e offscreen.\nMachado/picareta coletam • Enxada prepara • E planta/colhe/abre • Regador molha.\nCultivar/Construir escolhe peças • Bolsa organiza • J/Attack: toque ou segure/solte • Space: esquiva.", 18))
	controls.add_child(ShellUI.label_text("Perfis isolados de QA. Nenhum reset afeta suas jornadas reais.", 18))
	var notch := CheckButton.new()
	notch.name = "SimulateNotch"
	notch.text = "Simular recorte lateral e gesto inferior"
	notch.custom_minimum_size.y = 56
	notch.toggled.connect(func(enabled: bool) -> void:
		safe.simulated_insets = Vector4(80, 0, 40, 16) if enabled else Vector4.ZERO
		safe.refresh())
	controls.add_child(notch)
	var slots := HBoxContainer.new()
	controls.add_child(slots)
	for slot_id: String in SlotStore.SLOT_IDS:
		var button := ShellUI.button("Carregar " + slot_id, slot_id, Vector2(220, 56))
		button.pressed.connect(func() -> void: _load_slot(slot_id))
		slots.add_child(button)
	var saves := ShellUI.button("Abrir seleção de saves de teste", "TestSaveSelect")
	saves.pressed.connect(Flow.show_saves)
	controls.add_child(saves)
	confirmation = CheckButton.new()
	confirmation.name = "ConfirmReset"
	confirmation.text = "Confirmo apagar apenas os quatro perfis QA"
	confirmation.custom_minimum_size.y = 56
	controls.add_child(confirmation)
	var reset := ShellUI.button("Resetar dados de teste", "ResetQA")
	reset.disabled = true
	confirmation.toggled.connect(func(enabled: bool) -> void: reset.disabled = not enabled)
	reset.pressed.connect(_reset)
	controls.add_child(reset)
	var boot := ShellUI.button("Voltar ao Boot / saves reais", "ProductionBoot")
	boot.pressed.connect(func() -> void: get_tree().change_scene_to_file("res://scenes/boot/Boot.tscn"))
	controls.add_child(boot)
	get_viewport().size_changed.connect(_resolution)
	_resolution()

func _resolution() -> void:
	information.text = "Janela %s  •  Canvas %s  •  Safe area %s" % [get_window().size, get_viewport_rect().size, DisplayServer.get_display_safe_area()]

func _load_slot(slot_id: String) -> void:
	if Profiles.select_slot(slot_id) == OK:
		Flow.enter_main()

func _reset() -> void:
	if confirmation.button_pressed:
		var error := Profiles.reset_test_profiles()
		information.text = "Perfis QA apagados." if error == OK else "Falha ao resetar QA: %s" % error
		confirmation.button_pressed = false
