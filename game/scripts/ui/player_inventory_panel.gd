class_name PlayerInventoryPanel
extends Control
## Event-driven inventory view. No _process loop; hidden views do not rebuild.

var component: InventoryComponent
var selected_slot := -1
var _cells: Array[Button] = []
var _gear: Dictionary = {}
var _gear_titles := {"helmet":"Elmo", "chest":"Peitoral", "legs":"Calças", "accessory_1":"Acessório I", "accessory_2":"Acessório II"}
var _description: Label
var _feedback: Label
var _built := false

func configure(owner_component: InventoryComponent) -> void:
	component = owner_component
	component.open_changed.connect(_open_changed)
	component.state.changed.connect(func(_revision: int) -> void: _refresh())

func _ready() -> void:
	name = "InventoryPanel"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.04,0.09,0.12,0.92)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.offset_top = 178
	shade.offset_bottom = -108
	add_child(shade)
	var safe := ShellSafeArea.new()
	add_child(safe)
	var interior := MarginContainer.new()
	interior.add_theme_constant_override("margin_top", 154)
	interior.add_theme_constant_override("margin_bottom", 94)
	safe.add_child(interior)
	var content := VBoxContainer.new()
	interior.add_child(content)
	var header := HBoxContainer.new()
	content.add_child(header)
	var title := ShellUI.label_text("SUA BAGAGEM", 26, ShellUI.GOLD)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var close := ShellUI.button("Fechar", "CloseInventory", Vector2(130,48))
	close.pressed.connect(component.toggle)
	header.add_child(close)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	content.add_child(columns)
	var equipment := ShellUI.column(columns, 8)
	equipment.custom_minimum_size.x = 210
	equipment.add_child(ShellUI.label_text("EQUIPAMENTO", 18, ShellUI.GOLD))
	for entry: Array in [["helmet","Elmo"],["chest","Peitoral"],["legs","Calças"],["accessory_1","Acessório I"],["accessory_2","Acessório II"]]:
		var button := ShellUI.button(entry[1] + " — vazio", entry[0], Vector2(210,48))
		button.pressed.connect(func() -> void: _equip(entry[0]))
		equipment.add_child(button)
		_gear[entry[0]] = button
	var bag := ShellUI.column(columns, 8)
	bag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bag.add_child(ShellUI.label_text("INVENTÁRIO • 20 ESPAÇOS", 18, ShellUI.GOLD))
	var grid := GridContainer.new()
	grid.name = "InventoryGrid"
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	bag.add_child(grid)
	for index: int in range(InventoryState.CAPACITY):
		var cell := ShellUI.button("—", "Slot%02d" % index, Vector2(74,58))
		cell.add_theme_font_size_override("font_size", 18)
		cell.pressed.connect(func() -> void:
			selected_slot = index
			_refresh())
		grid.add_child(cell)
		_cells.append(cell)
	var detail := ShellUI.column(columns, 8)
	detail.custom_minimum_size.x = 225
	detail.add_child(ShellUI.label_text("ITEM SELECIONADO", 18, ShellUI.GOLD))
	_description = ShellUI.label_text("Escolha um item.", 18)
	detail.add_child(_description)
	detail.add_child(ShellUI.label_text("Atribuir à hotbar", 18, ShellUI.MUTED))
	var assignments := GridContainer.new()
	assignments.columns = 4
	detail.add_child(assignments)
	for index: int in range(8):
		var button := ShellUI.button(str(index+1), "Assign%d" % index, Vector2(50,44))
		button.pressed.connect(func() -> void:
			var error := component.state.assign_hotbar(index, selected_slot)
			_feedback.text = "Atribuído." if error == OK else "Este item não pode ir à hotbar.")
		assignments.add_child(button)
	_feedback = ShellUI.label_text("Toque no equipamento para equipar.", 16, ShellUI.MUTED)
	content.add_child(_feedback)
	_built = true
	visible = component.is_open

func _open_changed(open: bool) -> void:
	visible = open
	if open:
		_refresh()

func _refresh() -> void:
	if not _built or not visible:
		return
	for index: int in range(InventoryState.CAPACITY):
		var stack := component.state.slot_at(index)
		_cells[index].text = "—"
		if not stack.is_empty():
			var definition := ItemCatalog.resolve(stack.item_id)
			_cells[index].text = "%s %d" % [definition.icon, stack.quantity]
			_cells[index].tooltip_text = definition.title
		_cells[index].modulate = Color(1.3,1.2,0.85) if index == selected_slot else Color.WHITE
	for slot: String in InventoryState.EQUIPMENT:
		var stack := component.state.equipment_at(slot)
		_gear[slot].text = (_gear_titles[slot] + " — vazio") if stack.is_empty() else ItemCatalog.resolve(stack.item_id).title
	var selected := component.state.slot_at(selected_slot)
	_description.text = "Escolha um item."
	if not selected.is_empty():
		var definition := ItemCatalog.resolve(selected.item_id)
		_description.text = "%s\n%s\n%d / %d" % [definition.title, definition.category_title(), selected.quantity, definition.max_stack]

func _equip(slot: String) -> void:
	var selected := component.state.slot_at(selected_slot)
	var current := component.state.equipment_at(slot)
	var index := -1 if not current.is_empty() and not selected.is_empty() and current.stack_uid == selected.stack_uid else selected_slot
	var error := component.state.equip(slot, index)
	_feedback.text = "Equipamento atualizado." if error == OK else "Escolha um item compatível."
