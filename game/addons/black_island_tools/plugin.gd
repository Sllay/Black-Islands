@tool
extends EditorPlugin
const Tab = preload("res://addons/black_island_tools/content_tab.gd")
var dock: VBoxContainer
var tabs: TabContainer
var issues: ItemList
var detail: Label
var qa_runner: RefCounted
func _enter_tree() -> void:
	dock = VBoxContainer.new()
	dock.name = "BlackIslandTools"
	dock.custom_minimum_size = Vector2(650,440)
	var title := Label.new()
	title.text = "BLACK ISLAND TOOLS"
	dock.add_child(title)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dock.add_child(tabs)
	for section: String in ["items","weapons","recipes"]:
		var tab: Control = load("res://addons/black_island_tools/weapons_tab.gd").new() if section == "weapons" else Tab.new()
		tab.name = section.capitalize()
		if section != "weapons": tab.section = section
		tabs.add_child(tab)
	var validation := VBoxContainer.new()
	validation.name = "Validation"
	tabs.add_child(validation)
	var run := Button.new()
	run.text = "Validate all runtime content"
	run.pressed.connect(validate_all)
	validation.add_child(run)
	issues = ItemList.new()
	issues.custom_minimum_size = Vector2(300,320)
	issues.size_flags_vertical = Control.SIZE_EXPAND_FILL
	issues.item_selected.connect(func(index: int) -> void:
		var issue: Dictionary = issues.get_item_metadata(index)
		detail.text = "%s\n%s\n%s"%[issue.file,issue.definition,issue.message])
	validation.add_child(issues)
	detail = Label.new()
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	validation.add_child(detail)
	add_control_to_bottom_panel(dock,"Black Island Tools")
	validate_all()
	if OS.get_environment("BI_CONTENT_EDITOR_QA") == "1":
		qa_runner = load("res://tests/editor/content_editor_qa.gd").new()
		qa_runner.run.call_deferred(self)
func validate_all() -> void:
	ContentData.reload()
	issues.clear()
	for issue: Dictionary in ContentValidator.validate(ContentData.all()):
		var index := issues.add_item("%s • %s • %s"%[issue.severity,issue.definition,issue.message])
		issues.set_item_metadata(index,issue)
		issues.set_item_custom_fg_color(index,Color.CORAL if issue.severity == "ERROR" else (Color.GOLD if issue.severity == "WARNING" else Color.LIGHT_GREEN))
func _exit_tree() -> void:
	remove_control_from_bottom_panel(dock)
	dock.queue_free()
