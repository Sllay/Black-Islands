class_name InventorySlotView
extends PanelContainer
## Passive slot presentation. All gestures and mutations are delegated.
var store: InventoryState
var index := 0
var kind := "inventory"
var equipment_key := ""
var gestures: InventoryGestureController
var title: Label
var bar: ProgressBar
var row: Dictionary = {}
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	custom_minimum_size = Vector2(64,58)
	var style := StyleBoxFlat.new()
	style.bg_color = Color("18343e")
	style.border_color = ShellUI.GOLD.darkened(.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.set_content_margin_all(5)
	add_theme_stylebox_override("panel",style)
	title = ShellUI.label_text("—",20)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title)
	bar = ProgressBar.new()
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.show_percentage = false
	bar.max_value = 1
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_left = 5
	bar.offset_right = -5
	bar.offset_top = 3
	bar.offset_bottom = 8
	bar.custom_minimum_size.y = 5
	var background := StyleBoxFlat.new()
	background.bg_color = Color("071319")
	bar.add_theme_stylebox_override("background",background)
	add_child(bar)
	refresh()
func refresh() -> void:
	if title == null or store == null:
		return
	row = store.hotbar_at(index) if kind == "hotbar" else (store.equipment_at(equipment_key) if kind == "equipment" else store.slot_at(index))
	title.text = str(index+1) if kind == "hotbar" else (str({"helmet":"Elmo","chest":"Peitoral","legs":"Calças","accessory_1":"Acessório I","accessory_2":"Acessório II"}.get(equipment_key,"Equipamento")) if kind == "equipment" else "—")
	tooltip_text = ""
	if not row.is_empty():
		var definition := ItemCatalog.resolve(row.item_id)
		title.text = ("%s\n%d" if kind == "hotbar" else "%s  %d")%[definition.icon,row.quantity]
		title.add_theme_font_size_override("font_size",16 if kind == "hotbar" else 20)
		tooltip_text = definition.title
	update_freshness()
func update_freshness() -> void:
	bar.visible = not row.is_empty() and not ItemCatalog.resolve(row.item_id).spoilage.is_empty()
	if not bar.visible:
		return
	bar.value = StackPolicy.freshness(row,store.time_source.now)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("74bd6b") if bar.value > .7 else (Color("e8cb58") if bar.value > .45 else (Color("e99b42") if bar.value > .2 else Color("d65b54")))
	bar.add_theme_stylebox_override("fill",fill)
func _gui_input(event: InputEvent) -> void:
	if gestures != null:
		gestures.slot_event(self,event)
