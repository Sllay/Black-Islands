extends Node
## Small domain/presentation gate; native terrain traversal is a separate test.
var failures := 0

func _ready() -> void:
	_run.call_deferred()

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("P03_C02 " + label)

func _run() -> void:
	_inventory()
	var player: PlayerActor = load("res://scenes/player/Player.tscn").instantiate()
	player.position = Vector3.ZERO
	add_child(player)
	player.set_physics_process(false)
	_lpc(player)
	var panel: PlayerInventoryPanel = load("res://scenes/ui/PlayerInventory.tscn").instantiate()
	panel.configure(player.inventory)
	add_child(panel)
	_check(not panel.visible and not panel.is_processing(), "closed inventory has no processing loop")
	player.inventory.toggle()
	_check(panel.visible and panel.find_child("InventoryGrid", true, false).get_child_count() == 20, "visible inventory exactly 5x4")
	_check(panel._gear.size() == 5, "five equipment slots")
	player.inventory.toggle()
	_check(not panel.visible, "inventory closes")
	print("P03_C02 PASS failures=", failures, " cache=", LPCCompositionCache.report())
	get_tree().quit(1 if failures else 0)

func _inventory() -> void:
	var limits := {"bi.resource.stone":256, "bi.food.coconut":32, "bi.tool.stone_pick":1,
		"bi.weapon.starter_sword":1, "bi.armor.fiber_hat":1, "bi.accessory.shell_charm":1,
		"bi.build.foundation":12, "bi.ammo.arrow":999}
	for id: String in limits:
		var state := InventoryState.new()
		var limit := int(limits[id])
		_check(state.add_item(id, limit + 1) == 0, "add " + id)
		_check(state.slot_at(0).quantity == limit and state.slot_at(1).quantity == 1, "stack cap " + id)
		_check(state.slot_at(0).stack_uid != state.slot_at(1).stack_uid, "stable independent stack IDs")
	var bag := InventoryState.new()
	bag.add_item("bi.weapon.starter_sword", 1)
	bag.add_item("bi.resource.stone", 300)
	bag.add_item("bi.armor.fiber_hat", 1)
	bag.add_item("bi.accessory.shell_charm", 2)
	_check(bag.snapshot().slots.size() == 20 and bag.snapshot().hotbar.size() == 8, "20 inventory / 8 hotbar")
	_check(bag.assign_hotbar(0, 0) == OK, "weapon hotbar")
	_check(bag.assign_hotbar(1, 1) == ERR_INVALID_DATA, "resource rejected from hotbar")
	_check(bag.equip("helmet", 3) == OK and bag.equip("chest", 3) == ERR_INVALID_DATA, "equipment categories")
	_check(bag.equip("accessory_1", 4) == OK and bag.equip("accessory_2", 4) == ERR_ALREADY_IN_USE, "no duplicated equipment ownership")
	_check(bag.equip("accessory_2", 5) == OK, "distinct accessory instances")
	_check(bag.active_definition().id == "bi.weapon.starter_sword", "weapon derives from selected hotbar")
	_check(bag.equipment_defense() == 5.0, "equipment stat seam")
	var snapshot := bag.snapshot()
	var restored := InventoryState.new()
	_check(restored.restore(JSON.parse_string(JSON.stringify(snapshot))) == OK, "JSON reload")
	_check(restored.hotbar_at(0).stack_uid == bag.slot_at(0).stack_uid, "hotbar references same stack UID after reload")
	_check(restored.equipment_at("helmet").stack_uid == bag.slot_at(3).stack_uid, "equipment references same stack UID after reload")
	var broken := snapshot.duplicate(true)
	broken.slots[0].item_id = "unknown.asset"
	_check(restored.restore(broken) != OK and restored.active_definition().id == "bi.weapon.starter_sword", "invalid restore is atomic")
	var detached := bag.slot_at(0)
	detached.quantity = 100
	_check(bag.slot_at(0).quantity == 1, "UI receives copies, not inventory truth")
	_check(bag.consume_uid(bag.slot_at(0).stack_uid, 1) == OK and bag.hotbar_at(0).is_empty(), "consuming clears stale hotbar refs")
	_check(bag.wallet.get("bi.currency.coins") == 0 and ItemCatalog.resolve("bi.currency.coins") == null, "currency outside inventory")

func _lpc(player: PlayerActor) -> void:
	var visual := player.visual
	var appearance := visual.appearance
	_check(appearance != null and visual.get_child_count() == 1 and visual.sprite is Sprite3D, "one composed Sprite3D")
	var same_config := visual.configuration.duplicate(true)
	_check(LPCCompositionCache.obtain(same_config) == appearance, "normalized cache reuse")
	for action: String in [LPCActionResolver.IDLE, LPCActionResolver.MOVE, LPCActionResolver.MELEE_SLASH]:
		visual.play_semantic(action, 1.0)
		for heading: float in [0.0, PI*0.5]:
			for dir: Vector3 in [Vector3.FORWARD, Vector3.LEFT, Vector3.BACK, Vector3.RIGHT]:
				visual.tick(0.09, dir.rotated(Vector3.UP, heading), heading, action)
				_check(visual.sprite.texture != null, "semantic visual " + action)
	_check(appearance.clips.MOVE.frame_size == 64 and appearance.clips.MELEE_SLASH.frame_size == 192, "real 64 + oversized 192 clips")
	for action: String in appearance.clips:
		var clip: Dictionary = appearance.clips[action]
		var image: Image = clip.texture.get_image()
		for direction: int in range(4):
			for frame: int in range(int(clip.frames)):
				var rect := Rect2i(frame*int(clip.frame_size), direction*int(clip.frame_size), int(clip.frame_size), int(clip.frame_size))
				_check(image.get_region(rect).get_used_rect().has_area(), "non-empty frame " + action)
	for size: int in [64,128,192]:
		var pivot := LPCCompositionCache.foot_pivot(size)
		var offset := pivot - Vector2(size*0.5,size*0.5)
		_check(offset == Vector2(0,28) and is_zero_approx(size*0.5-pivot.y+offset.y), "Sprite3D foot vertex at physical origin " + str(size))
	_check(LPCActionResolver.direction(Vector3.FORWARD,0) == 0 and LPCActionResolver.direction(Vector3.FORWARD.rotated(Vector3.UP,PI*0.5),PI*0.5) == 0, "direction independent of camera heading")
	visual.play_semantic("MISSING_CLIP", 1)
	visual.tick(0.1, Vector3.BACK,0,LPCActionResolver.IDLE)
	_check(visual.fallback and visual.sprite.texture != null, "missing clip fallback remains visible")
	var textures := LPCCompositionCache.texture_creations
	var compositions := LPCCompositionCache.compositions
	for frame: int in range(300):
		visual.tick(1.0/60.0,Vector3.RIGHT,0,LPCActionResolver.MOVE)
	_check(textures == LPCCompositionCache.texture_creations and compositions == LPCCompositionCache.compositions, "no per-frame composition/upload")
	for asset: Dictionary in LPCCatalog.data().assets:
		_check(asset.legal_status == "accepted" and asset.license == "CC-BY-SA-3.0", "accepted asset license and provenance")
