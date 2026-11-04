extends Node
@onready var root: Window = get_tree().root
var failures := 0
var assertions := 0
class Target extends Node3D:
	var health := 100.0
	func receive_hit(hit: HitPayload) -> float:
		health -= hit.raw_damage
		return hit.raw_damage
func check(ok: bool,label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("CONTENT_B "+label)
func _ready() -> void:
	_run.call_deferred()
func _run() -> void:
	var player: PlayerActor = load("res://scenes/player/Player.tscn").instantiate()
	root.add_child(player)
	player.set_physics_process(false)
	player.state.set_health(40)
	player.inventory.state.add_item("bi.food.healing_fruit",1)
	var uid := ""
	for index: int in 20:
		var row := player.inventory.state.slot_at(index)
		if row.get("item_id") == "bi.food.healing_fruit": uid = row.stack_uid
	var controller := InventoryIntentController.new()
	controller.configure(player.inventory)
	check(controller.consume(player.inventory.state,uid,player.inventory.state.revision) == OK and player.state.current_health == 60,"consumable OnConsume ModifyStat transaction")
	check(player.inventory.state.record_by_uid(uid).is_empty(),"consumed exactly once")
	var target := Target.new()
	root.add_child(target)
	var hit := HitPayload.new()
	hit.raw_damage = 18
	check(EffectService.hit(player,target,hit,["bi.effect.weapon.damage"]) == 18 and target.health == 82,"OnHit damage")
	var context := EffectContext.new()
	context.stats.health = 40
	check(EffectGraph.prepare("bi.effect.heal.conditional","OnUse",context) == OK and context.stats.health == 50,"true condition")
	context.stats.health = 80
	check(EffectGraph.prepare("bi.effect.heal.conditional","OnUse",context) == OK and context.stats.health == 80,"false condition")
	check(EffectService.context_for(player,null,"event1").rng.seed != EffectService.context_for(player,null,"event2").rng.seed,"event entropy independent of inventory revision")
	var before := EffectGraph.compilations
	EffectGraph.prepare("bi.effect.heal.conditional","OnUse",context)
	check(EffectGraph.compilations == before,"compiled graph cache")
	var items := {}
	for record: Dictionary in ContentData.rows("items"): items[record.id] = true
	for graph: Dictionary in [
		{"id":"bad","nodes":[{"id":"x","type":"ScriptNode","next":[]}],"triggers":{"OnHit":"x"}},
		{"id":"bad","nodes":[{"id":"x","type":"Damage","amount":2,"next":["missing"]}],"triggers":{"OnHit":"x"}},
		{"id":"bad","nodes":[{"id":"x","type":"Damage","amount":2,"next":["x"]}],"triggers":{"OnHit":"x"}},
		{"id":"bad","nodes":[{"id":"x","type":"ModifyStat","stat":"execute","amount":2,"next":[]}],"triggers":{"OnUse":"x"}}]:
		var issues: Array = []
		ContentValidator.validate_graph(graph,{"items":items},issues)
		check(ContentValidator.has_errors(issues),"invalid graph blocked")
	var rig := player.weapon_rig
	check(not rig.sprite.visible and player.visual.configuration.equipment_visuals == ["lpc.weapon.sword"],"LPC layer no duplicate detached visual")
	player.visual.play_semantic(LPCActionResolver.MELEE_SLASH,.5)
	player.visual.tick(.1,Vector3.BACK,0,LPCActionResolver.IDLE)
	check(player.visual.action == LPCActionResolver.MELEE_SLASH and not player.visual.fallback,"compatible LPC action")
	rig.select(WeaponCatalog.visual("bi.visual.blade.detached"))
	rig.tick(0,0,"idle",0)
	var north := rig.sprite.position
	check(rig.layer == "BEHIND_CHARACTER","north behind")
	rig.tick(2,0,"idle",0)
	check(rig.layer == "FRONT_CHARACTER" and rig.sprite.position != north,"direction offset/front")
	rig.tick(2,0,"attack",.5)
	check(rig.trail.visible and not is_zero_approx(rig.sprite.rotation.z) and rig.sprite.texture != null,"detached attack curve and trail")
	rig.tick(2,0,"recovery",.9,.5)
	check(not rig.trail.visible,"trail duration bounded")
	rig.select(WeaponCatalog.visual("bi.visual.sword.lpc"))
	check(not rig.sprite.visible and rig.sprite.texture == null and not rig.trail.visible and rig.get_child_count() == 2,"switch cleans previous visual")
	rig.select(WeaponCatalog.visual("bi.visual.blade.detached"))
	rig.tick(2,0,"idle",0)
	check(not rig.trail.visible,"reselected detached has no orphan trail")
	var pivot_profile := WeaponVisualProfile.new(WeaponCatalog.visual("bi.visual.blade.detached").data)
	pivot_profile.data.pivot = [10,12]
	pivot_profile.data.trail_profile.texture = "res://assets/content/test_blade.svg"
	rig.select(pivot_profile)
	rig._textures.idle_texture = ImageTexture.create_from_image(Image.create_empty(64,32,false,Image.FORMAT_RGBA8))
	rig.tick(2,0,"idle",0)
	check(rig.sprite.offset == Vector2(22,-4) and rig._material.albedo_texture != null,"real texture pivot and trail texture")
	for speed: float in [.5,2.0]:
		player.visual.play_semantic(LPCActionResolver.MELEE_SLASH,1.0/speed,speed)
		player.visual.tick(.1,Vector3.BACK,0,LPCActionResolver.IDLE)
		check(is_equal_approx(player.visual._time,.1*speed),"LPC authored attack speed")
	context = EffectContext.new()
	context.damage_input = 20
	check(EffectGraph.prepare("bi.effect.weapon.fire_test","OnHit",context) == OK and context.events.size() == 1,"registered status seam")
	player.inventory.is_open = true
	var revision := player.inventory.state.revision
	Input.action_press("hotbar_8")
	player._read_hotbar()
	check(player.inventory.state.revision == revision,"numeric UI entry cannot mutate hotbar/revision")
	Input.action_release("hotbar_8")
	player.inventory.is_open = false
	Input.action_press("hotbar_8")
	player._read_hotbar()
	check(player.inventory.state.selected == 7,"hotbar gameplay shortcut remains functional")
	Input.action_release("hotbar_8")
	print("CONTENT_B ","PASS" if failures == 0 else "FAIL"," assertions=",assertions," failures=",failures)
	player.free()
	target.free()
	get_tree().quit(1 if failures else 0)
