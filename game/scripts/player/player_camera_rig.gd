class_name PlayerCameraRig
extends Node3D
## One physical camera, two reversible third-person compositions.

signal mode_changed(build: bool)
@export var transition_seconds := 0.35
@export var heading_degrees := 0.0
var build_mode := false
var benchmark_legacy := false
var overview := false
@export var aim_screen := Vector2(0.5, 0.58)
@export var shoulder_offset := Vector3(1.4,0,0)
@export var camera_distance := 4.6
@export var camera_height := 2.1
@export var camera_smoothing := 12.0
var blend := 0.0
var obstruction_count := 0
var _anchor := Vector3.ZERO
var _ray := PhysicsRayQueryParameters3D.new()
@onready var camera: Camera3D = $Camera
@onready var actor: CharacterBody3D = get_parent()

func _ready() -> void:
	reset_anchor()
	_ray.collision_mask = CollisionLayers.WALKABLE_BLOCKERS
	_ray.exclude = [actor.get_rid()]

func reset_anchor() -> void:
	_anchor = get_parent().global_position + Vector3.UP

func toggle_build() -> void:
	_preserve_aim()
	build_mode = not build_mode
	overview = false
	mode_changed.emit(build_mode)

enum GameplayMode { OVERVIEW, SHOULDER }
var gameplay_mode := GameplayMode.OVERVIEW
var _aim_anchor := Vector3.ZERO
var _keep_aim := false
signal view_changed(title: String)

func toggle_view() -> void:
	_preserve_aim()
	gameplay_mode = GameplayMode.SHOULDER if gameplay_mode == GameplayMode.OVERVIEW else GameplayMode.OVERVIEW
	view_changed.emit("Shoulder" if gameplay_mode == GameplayMode.SHOULDER else "Overview")

func _preserve_aim() -> void:
	var player := actor as PlayerActor
	_keep_aim = player != null and player.targeter.current.kind != TargetResult.Kind.NONE
	if _keep_aim:
		_aim_anchor = player.targeter.current.world_position

func planar_direction(axis: Vector2) -> Vector3:
	var right := Vector3.RIGHT.rotated(Vector3.UP, deg_to_rad(heading_degrees))
	var forward := Vector3.FORWARD.rotated(Vector3.UP, deg_to_rad(heading_degrees))
	return (right * axis.x - forward * axis.y).limit_length(1.0)

func tick(delta: float) -> void:
	var shoulder := build_mode or gameplay_mode == GameplayMode.SHOULDER
	blend = move_toward(blend,1.0 if shoulder else 0.0,delta/transition_seconds)
	_anchor = _anchor.lerp(actor.global_position+Vector3.UP,1.0-exp(-camera_smoothing*delta))
	var transition := smoothstep(0,1,blend)
	var shoulder_position := Vector3(shoulder_offset.x,camera_height+shoulder_offset.y,camera_distance+shoulder_offset.z)
	var offset := Vector3(0,9,13).lerp(shoulder_position,transition)
	var look := _anchor+(Vector3.FORWARD*lerpf(.8,2.5,transition)+Vector3.RIGHT*shoulder_offset.x*transition).rotated(Vector3.UP,deg_to_rad(heading_degrees))
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = lerpf(45,60,transition)
	if benchmark_legacy:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 36
		offset = Vector3(0,24,20)
		look = _anchor
	if overview:
		camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		camera.size = 550
		offset = Vector3(0,350,210)
	var desired := _anchor+offset.rotated(Vector3.UP,deg_to_rad(heading_degrees))
	_ray.from = _anchor
	_ray.to = desired
	var obstruction := actor.get_world_3d().direct_space_state.intersect_ray(_ray)
	if not obstruction.is_empty():
		desired = obstruction.position+obstruction.normal*.25
		obstruction_count += 1
	camera.global_position = desired
	camera.look_at(look)
	if _keep_aim and not camera.is_position_behind(_aim_anchor):
		aim_screen = (camera.unproject_position(_aim_anchor)/get_viewport().get_visible_rect().size).clamp(Vector2(.05,.05),Vector2(.95,.95))
	if is_equal_approx(blend,1.0 if shoulder else 0.0): _keep_aim = false

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("camera_mode"):
		toggle_view()
	if not build_mode:
		return
	if event is InputEventMouseMotion or event is InputEventScreenDrag or event is InputEventScreenTouch:
		_keep_aim = false
		aim_screen = (event.position/get_viewport().get_visible_rect().size).clamp(Vector2(.05,.05),Vector2(.95,.95))
