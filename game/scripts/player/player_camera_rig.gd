class_name PlayerCameraRig
extends Node3D
## One physical camera, two reversible third-person compositions.

signal mode_changed(build: bool)
@export var transition_seconds := 0.35
@export var heading_degrees := 0.0
var build_mode := false
var benchmark_legacy := false
var overview := false
var aim_screen := Vector2(0.5, 0.58)
var blend := 0.0
var obstruction_count := 0
var _anchor := Vector3.ZERO
var _ray := PhysicsRayQueryParameters3D.new()
@onready var camera: Camera3D = $Camera
@onready var actor: CharacterBody3D = get_parent()

func _ready() -> void:
	reset_anchor()
	_ray.collision_mask = 1
	_ray.exclude = [actor.get_rid()]

func reset_anchor() -> void:
	_anchor = get_parent().global_position + Vector3.UP

func toggle_build() -> void:
	build_mode = not build_mode
	overview = false
	aim_screen = Vector2(0.5, 0.58)
	mode_changed.emit(build_mode)

func planar_direction(axis: Vector2) -> Vector3:
	var right := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(heading_degrees))
	var forward := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(heading_degrees))
	return (right * axis.x - forward * axis.y).limit_length(1.0)

func tick(delta: float) -> void:
	blend = move_toward(blend, 1.0 if build_mode else 0.0, delta / transition_seconds)
	_anchor = _anchor.lerp(actor.global_position + Vector3.UP * (0.9 if benchmark_legacy else 1.0), 1.0 - exp(-12.0 * delta))
	var offset := Vector3(0, 16, 14).lerp(Vector3(0, 4, 7), smoothstep(0, 1, blend))
	var look := _anchor + Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(heading_degrees)) * lerpf(0.5, 2.0, blend)
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = lerpf(34.0, 52.0, blend)
	if benchmark_legacy:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 36
		offset = Vector3(0, 24, 20)
		look = _anchor
	if overview:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 550
		offset = Vector3(0, 350, 210)
	var desired := _anchor + offset.rotated(Vector3.UP, deg_to_rad(heading_degrees))
	_ray.from = _anchor
	_ray.to = desired
	var obstruction := actor.get_world_3d().direct_space_state.intersect_ray(_ray)
	if not obstruction.is_empty():
		desired = obstruction.position + obstruction.normal * 0.25
		obstruction_count += 1
	camera.global_position = desired
	camera.look_at(look)

func _unhandled_input(event: InputEvent) -> void:
	if not build_mode:
		return
	if event is InputEventMouseMotion or event is InputEventScreenDrag or event is InputEventScreenTouch:
		aim_screen = (event.position / get_viewport().get_visible_rect().size).clamp(Vector2(0.05, 0.05), Vector2(0.95, 0.95))
