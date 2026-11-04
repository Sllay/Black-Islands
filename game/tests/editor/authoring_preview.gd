extends Control
## QA mirror of the same editor controls; not part of production gameplay UI.
var tabs: TabContainer
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var body := VBoxContainer.new()
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(body)
	var label := Label.new()
	label.text = "BLACK ISLAND TOOLS • editor-control QA mirror"
	body.add_child(label)
	tabs = TabContainer.new()
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(tabs)
	for section: String in ["items","weapons","recipes"]:
		var tab: Control = load("res://addons/black_island_tools/weapons_tab.gd").new() if section == "weapons" else load("res://addons/black_island_tools/content_tab.gd").new()
		tab.name = section.capitalize()
		if section != "weapons": tab.section = section
		tabs.add_child(tab)
	var validation := RichTextLabel.new()
	validation.name = "Validation"
	for issue: Dictionary in ContentValidator.validate(ContentData.all()): validation.append_text("%s %s %s\n"%[issue.severity,issue.definition,issue.message])
	tabs.add_child(validation)
func qa_tab(index: int) -> void:
	tabs.current_tab = index
