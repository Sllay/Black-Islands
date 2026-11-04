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
	print("CONTENT_A ","PASS" if failures == 0 else "FAIL"," assertions=",assertions," failures=",failures)
	quit(1 if failures else 0)
