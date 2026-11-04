@tool
extends VBoxContainer
const Form = preload("res://addons/black_island_tools/data_form.gd")
var section := "items"
var selector: OptionButton
var form: VBoxContainer
var message: Label
var original_id := ""
func _ready() -> void:
	var row := HBoxContainer.new()
	add_child(row)
	selector = OptionButton.new()
	selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector.item_selected.connect(func(index: int) -> void: select_record(selector.get_item_text(index)))
	row.add_child(selector)
	var fresh := Button.new()
	fresh.text = "New"
	fresh.pressed.connect(func() -> void:
		original_id = ""
		form.build(ContentSchema.prototype(section)))
	row.add_child(fresh)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(300,360)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(scroll)
	form = Form.new()
	form.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(form)
	var actions := HBoxContainer.new()
	add_child(actions)
	for title: String in ["Validate","Save","Reload"]:
		var button := Button.new()
		button.text = title
		button.pressed.connect(func() -> void:
			if title == "Reload":
				ContentData.reload()
				reload_records()
			else:
				publish(title == "Save"))
		actions.add_child(button)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(message)
	reload_records()
func reload_records() -> void:
	selector.clear()
	for record: Dictionary in ContentData.rows(section): selector.add_item(record.id)
	if selector.item_count > 0: select_record(selector.get_item_text(0))
	else:
		original_id = ""
		form.build(ContentSchema.prototype(section))
func select_record(id: String) -> void:
	original_id = id
	form.build(ContentData.find(section,id).duplicate(true))
func candidate() -> Dictionary:
	var result := ContentData.all().duplicate(true)
	var rows: Array = result[ContentData.GROUPS[section]][section]
	var index := -1
	for cursor: int in rows.size():
		if rows[cursor].id == original_id: index = cursor
	if index >= 0: rows[index] = form.data.duplicate(true)
	else: rows.append(form.data.duplicate(true))
	return result
func publish(save: bool) -> Error:
	if not original_id.is_empty() and form.data.get("id") != original_id:
		message.text = "ERROR: Existing stable IDs cannot be renamed. Create a new definition."
		return ERR_INVALID_DATA
	var data := candidate()
	var issues := ContentValidator.validate(data)
	var lines := PackedStringArray()
	for issue: Dictionary in issues:
		lines.append("%s %s: %s"%[issue.severity,issue.definition,issue.message])
	message.text = "\n".join(lines)
	if ContentValidator.has_errors(issues): return ERR_INVALID_DATA
	if save:
		var error := ContentData.write_bundle(data,ContentData.GROUPS[section])
		if error != OK: return error
		original_id = str(form.data.id)
		message.text = "Saved validated runtime data: "+original_id
	return OK
