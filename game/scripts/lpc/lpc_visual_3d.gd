class_name LPCVisual3D
extends Node3D
## Exactly one runtime Sprite3D, foot-anchored even for oversized clips.
var appearance: LPCAppearance
var configuration: Dictionary
var action := ""
var direction := 2
var fallback := false
var _clip: Dictionary = {}
var _pose := false
var _time := 0.0
var _forced_remaining := 0.0
var _forced_action := ""
@onready var sprite: Sprite3D = $Sprite3D

func set_appearance(config: Dictionary) -> void:
	var next := LPCCompositionCache.obtain(config)
	if next == appearance or next == null:
		return
	appearance = next
	configuration = next.config.duplicate(true)
	var previous := action
	action = ""
	_set_action(previous if not previous.is_empty() else LPCActionResolver.IDLE)

func play_semantic(semantic: String, duration: float = 0.5) -> void:
	_forced_action = semantic
	_forced_remaining = maxf(duration, 0.0)
	_set_action(semantic)
	_time = 0.0

func tick(delta: float, world_direction: Vector3, heading: float, locomotion: String) -> void:
	_forced_remaining = maxf(0.0, _forced_remaining - delta)
	_set_action(_forced_action if _forced_remaining > 0.0 else locomotion)
	direction = LPCActionResolver.direction(world_direction, heading, direction)
	_time += delta
	var frame := 0
	if not _pose:
		var elapsed := int(_time * float(_clip.fps))
		frame = elapsed % int(_clip.frames) if _clip.loop else mini(elapsed, int(_clip.frames)-1)
	var coords := Vector2i(frame, direction)
	if sprite.frame_coords != coords:
		sprite.frame_coords = coords

func _set_action(next: String) -> void:
	if next == action or appearance == null:
		return
	action = next
	_time = 0.0
	var resolved := LPCActionResolver.resolve(action, appearance)
	_pose = resolved.pose
	fallback = resolved.fallback
	_clip = appearance.clips[resolved.clip]
	sprite.frame = 0
	sprite.texture = _clip.texture
	sprite.hframes = int(_clip.frames)
	sprite.vframes = 4
	var size := float(_clip.frame_size)
	# SpriteBase3D's positive Y offset moves art up (opposite image coordinates).
	sprite.offset = Vector2(_clip.pivot) - Vector2(size*0.5, size*0.5)

func report() -> Dictionary:
	return {"action":action, "direction":["UP","LEFT","DOWN","RIGHT"][direction],
		"fallback":fallback, "frame":sprite.frame_coords, "frame_size":_clip.get("frame_size"),
		"appearance_key":appearance.key, "sprite_count":get_child_count(), "cache":LPCCompositionCache.report()}
