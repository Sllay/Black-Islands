class_name WeaponTrailProfile
extends RefCounted
var enabled := false
var width := .1
var duration := .12
var color := Color("d9f3c8")
var texture := ""
func _init(data: Dictionary = {}) -> void:
	enabled = bool(data.get("enabled",false))
	width = float(data.get("width",.1))
	duration = float(data.get("duration",.12))
	color = Color(data.get("color","d9f3c8"))
	texture = data.get("texture","")
