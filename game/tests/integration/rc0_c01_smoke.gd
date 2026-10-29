extends Node
var failures := 0

func _ready() -> void:
	_run.call_deferred()

func check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("RC0_C01 "+label)

func _run() -> void:
	var directory := "user://qa_rc0_c01/"+Crypto.new().generate_random_bytes(8).hex_encode()
	var library := FrontendLibrary.new(directory)
	check(library.summaries("world").size() == 5 and library.summaries("player").size() == 5,"five independent slots")
	for slot: int in range(1,6):
		check(library.create_world(slot,"Mundo_%03d"%slot,424242+slot) == OK,"world metadata create")
	check(library.create_world(6,"Overflow",1) != OK,"world capacity")
	var world := library.read("world",1)
	check(not world.generated and not FileAccess.file_exists(library.world_directory(world).path_join("active.json")),"creation does not generate terrain")
	var world_doc := library.document("world",1)
	world_doc.read()
	world_doc.loaded.generated = true
	world_doc.commit(world_doc.loaded)
	check(library.edit_world(1,"Renamed",999) == ERR_UNAUTHORIZED,"generated seed locked")
	check(library.edit_world(1,"Renamed",424243) == OK,"world rename")
	for body: String in ["male","female"]:
		var config := LPCCustomization.default_for(body)
		check(not LPCCatalog.normalize(config).is_empty(),"compatible "+body)
		check(LPCCompositionCache.obtain(config) != null,"real composed "+body)
	check("pregnant" not in LPCCustomization.body_types(),"pregnancy excluded")
	for slot: int in range(1,6):
		check(library.create_player(slot,"Player%d"%slot,LPCCustomization.default_for("female" if slot == 2 else "male")) == OK,"portable player create")
	check(library.create_player(6,"Overflow",LPCCatalog.default_appearance()) != OK,"player capacity")
	var player := library.read("player",1)
	check(not player.has("world_id") and not player.has("world_seed"),"player metadata has no world ownership")
	var changed := LPCCustomization.select(player.appearance,"body",LPCCustomization.options("body","male")[1].id)
	check(library.edit_player(1,changed) == ERR_UNAUTHORIZED,"immutable identity rejected")
	changed = LPCCustomization.select(player.appearance,"torso",LPCCustomization.options("torso","male")[1].id)
	check(library.edit_player(1,changed) == OK,"wardrobe edit")
	var owner_id: String = library.read("player",1).player_id
	check(library.trash("world",1) == OK and library.read("player",1).player_id == owner_id,"world deletion preserves character")
	GameSettings.path = directory.path_join("settings.json")
	GameSettings.load_settings()
	var original := GameSettings.current.duplicate(true)
	var options: Control = load("res://scenes/ui/Options.tscn").instantiate()
	add_child(options)
	var applied := GameSettings.apply_count
	options.values.Music.value = 0
	options.values.Distance.value = 10
	check(GameSettings.current == original and GameSettings.apply_count == applied,"sliders are staged")
	options._tab(1)
	check(options.footer.visible and not options.audio_page.visible and options.graphics_page.visible,"full screen tabs preserve bottom actions")
	check(GameSettings.save(options.staged) == OK,"confirm settings")
	var music := AudioServer.get_bus_index("Music")
	check(music >= 0 and AudioServer.is_bus_mute(music),"zero mutes bus")
	var audio := AudioServer.get_bus_index("Audio")
	check(is_equal_approx(AudioServer.get_bus_volume_db(audio),linear_to_db(.8)) and AudioServer.get_bus_send(audio) == "Master","linear volume to dB and bus routing")
	GameSettings.current = {}
	check(GameSettings.load_settings() == OK and GameSettings.current.distance == 10 and GameSettings.current.audio.Music == 0,"settings reload")
	for level: int in range(2,11):
		var budget := GameSettings.distance_budget(level)
		check(budget.viewer_metres >= 128 and budget.near_ring >= 1,"distance budget mapping")
	options.queue_free()
	var a := AtomicDocument.new(directory.path_join("a.json"),1,{"id":"A"})
	var b := AtomicDocument.new(directory.path_join("b.json"),1,{"id":"B"})
	a.commit({"quantity":10})
	b.commit({"quantity":0})
	var journal := directory.path_join("pending.json")
	check(AtomicBatch.commit(journal,[a,b],[{"quantity":6},{"quantity":4}]) == OK and a.loaded.quantity+b.loaded.quantity == 10,"cross-owner atomic batch")
	var pending := AtomicDocument.new(journal,1,{"kind":"ownership_commit"})
	pending.commit({"participants":[{"path":a.path,"schema":1,"identity":a.identity,"revision":a.revision,"data":{"quantity":3}},
		{"path":b.path,"schema":1,"identity":b.identity,"revision":b.revision,"data":{"quantity":7}}]})
	a.commit({"quantity":3}) # Interrupted after first participant.
	check(AtomicBatch.recover(journal) == OK,"interrupted batch recovery")
	a.read()
	b.read()
	check(a.loaded.quantity+b.loaded.quantity == 10 and b.loaded.quantity == 7,"recovery conservation")
	print("RC0_C01 ","PASS" if failures == 0 else "FAIL"," failures=",failures)
	get_tree().quit(1 if failures else 0)
