@tool
extends TabContainer
const Tab = preload("res://addons/black_island_tools/content_tab.gd")
func _ready() -> void:
	for section: String in ["weapons","visual_profiles","effects","movesets"]:
		var tab := Tab.new()
		tab.name = {"weapons":"Definition","visual_profiles":"Visual","effects":"Effects","movesets":"Moveset"}[section]
		tab.section = section
		add_child(tab)
