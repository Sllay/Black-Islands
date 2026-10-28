extends Node
## Deliberately small integration gate: isolated disk metadata + actual scene flow.

const TEST_DIRECTORY := "user://qa_p01_smoke"

class RejectingStore extends SlotStore:
	func write_slot(_metadata: Dictionary) -> Error:
		return ERR_FILE_CANT_WRITE

var failures: int = 0
var tree: SceneTree
var root: Window
var current_scene: Node:
	get: return tree.current_scene

func _ready() -> void:
	tree = get_tree()
	root = tree.root
	# Keep only this test controller alive while real production scenes change.
	tree.current_scene = null
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("P01 FAIL: " + label)

func _frames(count: int = 4) -> void:
	for index: int in range(count):
		await tree.process_frame

func change_scene_to_file(scene_path: String) -> void:
	tree.change_scene_to_file(scene_path)

func _clean() -> void:
	for slot_id: String in SlotStore.SLOT_IDS:
		for suffix: String in [".json", ".json.bak", ".json.tmp"]:
			var path := TEST_DIRECTORY.path_join(slot_id + suffix)
			if FileAccess.file_exists(path):
				DirAccess.remove_absolute(path)

func _run() -> void:
	_clean()
	_check(ProjectSettings.get_setting("application/run/main_scene") == "res://scenes/boot/Boot.tscn", "configured Boot")
	for scene_path: String in ["boot/Boot", "ui/SaveSelect", "main/Main", "ui/ProductionHUD", "debug/SeasonTest"]:
		var resource := load("res://scenes/" + scene_path + ".tscn") as PackedScene
		_check(resource != null, "load " + scene_path)
		if resource:
			var instance := resource.instantiate()
			_check(instance != null, "instantiate " + scene_path)
			instance.free()
	for action: String in ["move_left", "move_right", "move_up", "move_down", "interact", "attack_primary", "attack_heavy", "skill", "ultimate", "dodge", "guard", "inventory", "build_mode", "pause"]:
		_check(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(), "binding " + action)
	change_scene_to_file("res://scenes/boot/Boot.tscn")
	await _frames()
	_check(current_scene.name == "SaveSelect", "Boot → SaveSelect")
	Profiles.store = SlotStore.new(TEST_DIRECTORY)
	Profiles.selected_slot_id = ""
	Flow.show_saves()
	await _frames()
	_check(current_scene.find_children("Slot*", "Button", true, false).size() == 4, "exactly four cards")
	current_scene.get_node("SafeArea/Center/Content/Slots/Slot01").emit_signal("pressed")
	await _frames()
	_check(current_scene.name == "Main", "create → Main")
	var first := Profiles.current_profile()
	_check(first.get("schema_version") == 1 and first.get("slot_id") == "slot_01", "schema / stable slot")
	var store := SlotStore.new(TEST_DIRECTORY)
	_check(store.read_slot("slot_01").metadata.save_id == first.save_id, "reload preserves save identity")
	Profiles.store = store
	for slot_id: String in SlotStore.SLOT_IDS:
		_check(Profiles.select_slot(slot_id) == OK, "select/create " + slot_id)
	_check(Profiles.select_slot("../outside") != OK, "reject invalid slot identity")
	_check(Profiles.reset_test_profiles() == ERR_UNAUTHORIZED, "reset rejects non-QA namespace")
	var selected_before: String = Profiles.selected_slot_id
	var rejecting := RejectingStore.new()
	rejecting.directory = TEST_DIRECTORY
	Profiles.store = rejecting
	_check(Profiles.select_slot("slot_02") == ERR_FILE_CANT_WRITE, "failed write propagates")
	_check(Profiles.selected_slot_id == selected_before, "failed write does not change selection")
	Profiles.store = store
	var interrupted := FileAccess.open(TEST_DIRECTORY.path_join("slot_03.json.tmp"), FileAccess.WRITE)
	interrupted.store_string("{unfinished")
	interrupted.close()
	_check(store.read_slot("slot_03").state == "ready", "incomplete temp does not replace primary")
	# Valid backup remains usable after a truncated primary; future schema is preserved.
	_check(Profiles.select_slot("slot_01") == OK, "write backup")
	var primary_path := TEST_DIRECTORY.path_join("slot_01.json")
	var file := FileAccess.open(primary_path, FileAccess.WRITE)
	file.store_string("{truncated")
	file.close()
	_check(store.read_slot("slot_01").get("recovered", false), "backup recovery")
	_check(Profiles.select_slot("slot_01") == OK, "recovered slot can be selected")
	var future: Dictionary = Profiles.current_profile()
	future.schema_version = 99
	var future_json := JSON.stringify(future)
	file = FileAccess.open(primary_path, FileAccess.WRITE)
	file.store_string(future_json)
	file.close()
	_check(Profiles.select_slot("slot_01") != OK, "reject future schema despite old backup")
	_check(FileAccess.get_file_as_string(primary_path) == future_json, "future data not overwritten")
	_check(Profiles.select_slot("slot_02") == OK, "existing slot selection")
	Flow.enter_main()
	await _frames()
	var hud := current_scene.get_node("Canvas/MainView/ProductionHUD")
	_check(hud.find_children("Hotbar*", "Button", true, false).size() == 8, "eight hotbar buttons")
	var movement := hud.find_child("MoveUp", true, false) as Button
	movement.emit_signal("button_down")
	_check(Input.is_action_pressed("move_up"), "touch shell emits semantic action")
	movement.emit_signal("button_up")
	_check(not Input.is_action_pressed("move_up"), "touch shell releases semantic action")
	var health_width: float = hud.find_child("Health", true, false).get_child(1).size.x
	var stamina_width: float = hud.find_child("Stamina", true, false).get_child(1).size.x
	var mana_width: float = hud.find_child("Mana", true, false).get_child(1).size.x
	_check(health_width > stamina_width and stamina_width > mana_width, "resource staircase hierarchy")
	for resolution: Vector2i in [Vector2i(1280, 720), Vector2i(1920, 864)]:
		root.size = resolution
		await _frames()
		for button: Node in hud.find_children("*", "Button", true, false):
			var rect: Rect2 = button.get_global_rect()
			_check(root.get_visible_rect().encloses(rect), "onscreen control %s at %s" % [button.name, resolution])
	var safe := hud.get_node("SafeArea") as ShellSafeArea
	safe.simulated_insets = Vector4(80, 0, 40, 16)
	safe.refresh()
	await _frames()
	_check(safe.get_theme_constant("margin_left") == 104 and safe.get_theme_constant("margin_bottom") == 40, "safe-area simulation conversion")
	change_scene_to_file("res://scenes/debug/SeasonTest.tscn")
	await _frames()
	_check(current_scene.name == "SeasonTest", "separate QA scene")
	_check(Profiles.store.directory == "user://qa_profiles", "QA namespace isolated")
	_check(current_scene.find_child("ResetQA", true, false).disabled, "explicit reset confirmation")
	_clean()
	print("P01_SMOKE ", "PASS" if failures == 0 else "FAIL", " failures=", failures)
	tree.quit(0 if failures == 0 else 1)
