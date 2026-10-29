extends Control

func _ready() -> void:
	print("FLOW Boot")
	Profiles.use_production_profiles()
	var migration := LegacySaveImport.run(Profiles.library)
	if migration.imported > 0 or not migration.errors.is_empty():
		print("DEV_SAVE_MIGRATION ",migration)
	GameSettings.load_settings()
	Flow.show_menu.call_deferred()
