@tool
extends VBoxContainer
## Structured fields, recursive arrays/modules. JSON is storage, never the editor UI.
var data: Dictionary
var context_key := ""
func build(record: Dictionary) -> void:
	data = record
	for child: Node in get_children():
		remove_child(child)
		child.queue_free()
	for key: String in data:
		_field(self,key,data[key],func(value: Variant) -> void: data[key] = value)
func _field(parent: VBoxContainer, key: String, value: Variant, update: Callable) -> void:
	var label := Label.new()
	label.text = key.replace("_"," ").capitalize()
	parent.add_child(label)
	if value is Dictionary:
		var nested := VBoxContainer.new()
		parent.add_child(nested)
		for part: String in value:
			_field(nested,part,value[part],func(next: Variant) -> void: value[part] = next)
		if key in ["triggers","resources","targets"]:
			var entry := HBoxContainer.new()
			nested.add_child(entry)
			var selector := OptionButton.new()
			var options: Array = ContentSchema.TRIGGERS if key == "triggers" else (["ROCK","TREE","CORPSE"] if key == "targets" else ContentData.rows("items").map(func(row: Dictionary) -> String: return row.id))
			for option: String in options: selector.add_item(option)
			entry.add_child(selector)
			var add := Button.new()
			add.text = "+ Reference"
			add.pressed.connect(func() -> void:
				var selected := selector.get_item_text(selector.selected)
				if not value.has(selected): value[selected] = "start" if key == "triggers" else 1.0
				build(data))
			entry.add_child(add)
		return
	if value is Array:
		var rows := VBoxContainer.new()
		parent.add_child(rows)
		for index: int in value.size():
			var line := HBoxContainer.new()
			rows.add_child(line)
			var body := VBoxContainer.new()
			body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			line.add_child(body)
			_field(body,str(index+1),value[index],func(next: Variant) -> void: value[index] = next)
			var remove := Button.new()
			remove.text = "−"
			remove.pressed.connect(func() -> void:
				value.remove_at(index)
				build(data))
			line.add_child(remove)
		var add := Button.new()
		add.text = "+ " + key
		if key == "nodes":
			var types := OptionButton.new()
			for type: String in ContentSchema.EFFECT_TYPES: types.add_item(type)
			rows.add_child(types)
			add.pressed.connect(func() -> void:
				value.append(ContentSchema.effect_node(types.get_item_text(types.selected)))
				build(data))
		elif key == "modules":
			var types := OptionButton.new()
			for type: String in ContentSchema.MODULES: types.add_item(type)
			rows.add_child(types)
			add.pressed.connect(func() -> void:
				var type := types.get_item_text(types.selected)
				var module: Dictionary = ContentSchema.MODULES[type].duplicate(true)
				module.type = type
				value.append(module)
				build(data))
		else:
			add.pressed.connect(func() -> void:
				value.append(ContentSchema.array_default(key))
				build(data))
		rows.add_child(add)
		return
	if value is bool:
		var toggle := CheckBox.new()
		toggle.button_pressed = value
		toggle.toggled.connect(update)
		parent.add_child(toggle)
	elif value is int or value is float:
		var number := SpinBox.new()
		number.min_value = -100000
		number.max_value = 1000000
		number.step = 1 if value is int else .01
		number.value = value
		number.value_changed.connect(func(next: float) -> void: update.call(int(next) if value is int else next))
		parent.add_child(number)
	else:
		var choices: Array = []
		match key:
			"category": choices = ContentSchema.CATEGORIES
			"weapon_class": choices = ContentSchema.WEAPON_CLASSES
			"mode": choices = ["LPC_LAYER","DETACHED_SPRITE"]
			"type": choices = ContentSchema.MODULES.keys() if ContentSchema.MODULES.has(value) else ContentSchema.EFFECT_TYPES
		if not choices.is_empty():
			var pick := OptionButton.new()
			for option: String in choices: pick.add_item(option)
			pick.select(maxi(0,choices.find(value)))
			pick.item_selected.connect(func(index: int) -> void: update.call(choices[index]))
			parent.add_child(pick)
		else:
			var text := LineEdit.new()
			text.name = key
			text.text = str(value)
			text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			text.text_changed.connect(update)
			parent.add_child(text)
