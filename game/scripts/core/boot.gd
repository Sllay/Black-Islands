extends Control

func _ready() -> void:
	print("FLOW Boot")
	Flow.show_saves.call_deferred()
