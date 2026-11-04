extends Node3D
var players: Array[PlayerActor] = []
var elapsed := 0.0
func _ready() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0,2.5,6)
	add_child(camera)
	camera.look_at(Vector3(0,1,0))
	camera.current = true
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-40,-30,0)
	add_child(light)
	for index: int in 2:
		var player: PlayerActor = load("res://scenes/player/Player.tscn").instantiate()
		player.position = Vector3(-1.3 if index == 0 else 1.3,0,0)
		add_child(player)
		player.set_physics_process(false)
		player.camera_rig.camera.current = false
		if index == 1:
			player.inventory.state.add_item("bi.weapon.test_blade",1)
			for slot: int in 20:
				if player.inventory.state.slot_at(slot).get("item_id") == "bi.weapon.test_blade":
					player.inventory.state.assign_hotbar(0,slot)
		players.append(player)
	camera.current = true
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var text := Label.new()
	text.text = "C03 weapon QA   |   LPC_LAYER (left)   |   DETACHED_SPRITE (right)"
	text.add_theme_font_size_override("font_size",24)
	text.position = Vector2(30,30)
	canvas.add_child(text)
func _process(delta: float) -> void:
	elapsed += delta
	for player: PlayerActor in players:
		player.visual.play_semantic(LPCActionResolver.MELEE_SLASH,1)
		player.visual.tick(.1,Vector3.BACK,0,LPCActionResolver.IDLE)
		player.weapon_rig.tick(2,0,"attack",.5)
