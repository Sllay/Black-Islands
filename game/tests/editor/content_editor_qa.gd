@tool
extends RefCounted
## Opt-in editor-only QA. Exercises real authoring tabs and validated writes.
func run(plugin: EditorPlugin) -> void:
	await plugin.get_tree().process_frame
	var item: VBoxContainer = plugin.tabs.get_child(0)
	item.original_id = "bi.food.healing_fruit" if not ContentData.find("items","bi.food.healing_fruit").is_empty() else ""
	var row := ContentSchema.prototype("items")
	row.id = "bi.food.healing_fruit"
	row.category = "CONSUMABLE"
	row.stack_limit = 32
	row.name_key = "item.healing_fruit.name"
	row.description_key = "item.healing_fruit.description"
	row.title = "Healing fruit"
	row.modules = [{"type":"ConsumableModule","effects":[],"legacy_effect":"restore_health","amount":20.0}]
	# Existing representative definition may acquire EffectGraph config in B.
	if not item.original_id.is_empty(): row = ContentData.find("items",item.original_id)
	item.form.build(row.duplicate(true))
	var field := item.form.get_node("icon") as LineEdit
	field.text = "✚"
	field.text_changed.emit(field.text)
	assert(item.publish(true) == OK)
	var recipes: VBoxContainer = plugin.tabs.get_child(2)
	recipes.select_record("bi.recipe.foundation")
	assert(recipes.publish(false) == OK and recipes.publish(true) == OK)
	plugin.validate_all()
	assert(not ContentValidator.has_errors(ContentValidator.validate(ContentData.all())))
	print("CONTENT_EDITOR_QA PASS items=",ContentData.rows("items").size()," recipe=bi.recipe.foundation plugin_open=true")
	plugin.make_bottom_panel_item_visible(plugin.dock)
	await plugin.get_tree().create_timer(2).timeout
	for index: int in 4:
		plugin.tabs.current_tab = index
		await plugin.get_tree().process_frame
		await plugin.get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := EditorInterface.get_base_control().get_viewport().get_texture().get_image()
		image.save_png("res://../harness/evidence/rc0-r3-content/tools-%s.png"%["items","weapons","recipes","validation"][index])
