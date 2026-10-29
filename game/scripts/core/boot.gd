extends Control

func _ready() -> void:
	print("FLOW Boot")
	Profiles.use_production_profiles()
	GameSettings.load_settings()
	Flow.show_menu.call_deferred()
