class_name RecipeCatalog
extends RefCounted
var definitions: Dictionary = {}
var nearby_radius := 12.0
func _init() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/crafting/catalog.json"))
	nearby_radius = float(data.nearby_radius)
	for row: Dictionary in data.recipes:
		var recipe := RecipeDefinition.new(row)
		if recipe.valid():
			definitions[recipe.id] = recipe
func resolve(id: String) -> RecipeDefinition:
	return definitions.get(id)
