extends SceneTree
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	for native_class: String in ["VoxelGeneratorGraph","VoxelLodTerrain","VoxelInstancer","LimboHSM","BTPlayer"]:
		if not ClassDB.class_exists(native_class):
			push_error("Missing runtime class: "+native_class)
			quit(1)
			return
	if change_scene_to_file("res://scenes/boot/Boot.tscn") != OK:
		quit(1)
		return
	await create_timer(.3).timeout
	if current_scene == null or current_scene.scene_file_path != "res://scenes/ui/MainMenu.tscn":
		push_error("Clean runtime Boot did not reach MainMenu")
		quit(1)
		return
	print("RUNTIME_CLONE PASS native_classes=5 Boot->MainMenu")
	quit()
