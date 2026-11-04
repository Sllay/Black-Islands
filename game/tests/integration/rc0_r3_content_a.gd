extends SceneTree
var failures := 0
var assertions := 0
func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("CONTENT_A "+label)
func _init() -> void:
	var bundle := ContentData.all().duplicate(true)
	check(not ContentValidator.has_errors(ContentValidator.validate(bundle)),"valid catalog")
	bundle.items.items.append(bundle.items.items[0].duplicate(true))
	check(ContentValidator.has_errors(ContentValidator.validate(bundle)),"duplicate rejected")
	bundle = ContentData.all().duplicate(true)
	bundle.recipes.recipes[0].outputs[0].item_id = "missing.item"
	check(ContentValidator.has_errors(ContentValidator.validate(bundle)),"missing output rejected")
	bundle = ContentData.all().duplicate(true)
	bundle.items.schema_version = 999
	check(ContentValidator.has_errors(ContentValidator.validate(bundle)),"future schema reject")
	var inventory := InventoryState.new()
	inventory.add_item("bi.weapon.starter_sword",1)
	inventory.add_item("bi.food.coconut",12)
	inventory.assign_hotbar(0,0)
	check(InventoryState.new().restore(JSON.parse_string(JSON.stringify(inventory.snapshot()))) == OK,"existing stable item IDs reload")
	check(ItemCatalog.resolve("bi.food.coconut").module("SpoilageModule").duration == 300,"module data loaded")
	check(RecipeCatalog.new().definitions.size() == 5,"same C02 recipes")
	check(not Engine.is_editor_hint(),"runtime no EditorPlugin")
	var original := ContentData.rows("items")[0].id as String
	var copy := ContentData.all()
	copy.items.items[0].id = "mutated.only.in.copy"
	check(not ContentData.find("items",original).is_empty(),"raw snapshot cannot mutate cache")
	for malformed: Variant in [null,0,"bad",[],{"schema_version":999}]:
		copy = ContentData.all()
		copy.items = malformed
		check(ContentValidator.has_errors(ContentValidator.validate(copy)),"malformed group safely rejected")
	copy = ContentData.all()
	copy.items.items.append({"id":"bad.module","category":"RESOURCE","modules":[0]})
	check(ContentValidator.has_errors(ContentValidator.validate(copy)),"malformed module safely rejected")
	copy = ContentData.all()
	var renamed := "bi.resource.renamed.only.in.candidate"
	for item: Dictionary in copy.items.items:
		if item.id == "bi.resource.wood": item.id = renamed
	for recipe: Dictionary in copy.recipes.recipes:
		for ingredient: Dictionary in recipe.ingredients:
			if ingredient.item_id == "bi.resource.wood": ingredient.item_id = renamed
	# Harvest-tool resource references also need updating in the selected group.
	for item: Dictionary in copy.items.items:
		for module: Dictionary in item.get("modules",[]):
			if module.get("resources",{}).has("bi.resource.wood"):
				module.resources[renamed] = module.resources["bi.resource.wood"]
				module.resources.erase("bi.resource.wood")
	check(ContentData.write_bundle(copy,"items") != OK,"single-file save cannot rely on unsaved recipe changes")
	for invalid_case: String in ["target_affinity","missing_efficiency","critical_range","prop_material","negative_reserve","spawn_reference","moveset_reference"]:
		var bad_bundle := ContentData.all()
		var bad_tool: Dictionary = bad_bundle.items.items.filter(func(item: Dictionary) -> bool: return item.id == "bi.tool.stone_pick")[0].modules[0]
		match invalid_case:
			"target_affinity": bad_tool.targets.ROCK = "not-a-number"
			"missing_efficiency": bad_tool.erase("efficiency")
			"critical_range": bad_tool.critical_chance = 4
			"prop_material": bad_bundle.props.props[0].visual.color = []
			"negative_reserve": bad_bundle.props.harvestables[0].reserves["bi.resource.stone"] = -1
			"spawn_reference": bad_bundle.props.spawn_tables[0].entries[0].prop_definition = "missing.prop"
			"moveset_reference": bad_bundle.weapons.weapons[0].moveset_id = "missing.moveset"
		check(ContentValidator.has_errors(ContentValidator.validate(bad_bundle)),"invalid content rejected before runtime: "+invalid_case)
	print("CONTENT_A ","PASS" if failures == 0 else "FAIL"," assertions=",assertions," failures=",failures)
	quit(1 if failures else 0)
