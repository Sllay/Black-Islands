extends Control

func _ready() -> void:
	print("FLOW Boot")
	Profiles.use_production_profiles()
	Flow.show_saves.call_deferred()
