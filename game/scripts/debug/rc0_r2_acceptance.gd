extends Node
## Isolated QA metadata, then the unchanged production Boot/frontend/gameplay.
## No production user slots/settings are overwritten by the acceptance flow.
func _ready() -> void:
	Profiles.library = FrontendLibrary.new("user://qa_r2_acceptance/"+Crypto.new().generate_random_bytes(6).hex_encode())
	var index := 1
	for seed_value: int in [424242,12345,8675309]:
		assert(Profiles.library.create_world(index,"Black Island • %d"%seed_value,seed_value) == OK)
		index += 1
	assert(Profiles.library.create_player(1,"Explorer",LPCCatalog.default_appearance()) == OK)
	get_tree().change_scene_to_file.call_deferred("res://scenes/boot/Boot.tscn")
