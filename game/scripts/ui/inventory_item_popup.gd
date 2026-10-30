class_name InventoryItemPopup
extends Control
signal action(key: String)
signal dismissed
var row: Dictionary
var freshness := 1.0
var actions: Dictionary = {}
var _buttons: VBoxContainer
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0,0,0,.6)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed:
			dismissed.emit())
	add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel",InventoryStyle.panel())
	panel.custom_minimum_size = Vector2(350,0)
	center.add_child(panel)
	var content := ShellUI.column(panel,10)
	var definition := ItemCatalog.resolve(row.item_id)
	content.add_child(ShellUI.label_text("%s  %s ×%d"%[definition.icon,definition.title,row.quantity],24,ShellUI.GOLD))
	var description := ShellUI.label_text(definition.description if not definition.description.is_empty() else definition.category_title(),18)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.x = 320
	content.add_child(description)
	if not definition.spoilage.is_empty():
		content.add_child(ShellUI.label_text("Frescor • %d%%"%roundi(freshness*100),18))
	_buttons = ShellUI.column(content,6)
	_show_actions()
func _clear() -> void:
	for child: Node in _buttons.get_children():
		_buttons.remove_child(child)
		child.queue_free()
func _button(text: String, key: String, callback: Callable) -> void:
	var button := ShellUI.button(text,key,Vector2(310,48))
	button.pressed.connect(callback)
	_buttons.add_child(button)
func _show_actions() -> void:
	_clear()
	for key: String in actions:
		if actions[key]:
			if key == "split":
				_button("Dividir","Split",_show_split)
			else:
				var title: String = {"consume":"Consumir","drop":"Soltar","unassign":"Retirar da barra","unequip":"Desequipar"}.get(key,key)
				_button(title,key,func() -> void: action.emit(key))
	_button("Fechar","CloseDetails",func() -> void: dismissed.emit())
func _show_split() -> void:
	_clear()
	for mode: String in ["one","half","all"]:
		var text: String = {"one":"Dividir 1","half":"Dividir metade","all":"Dividir todos"}[mode]
		_button(text,"Split_"+mode,func() -> void: action.emit("split_"+mode))
	_button("Voltar","BackDetails",_show_actions)
