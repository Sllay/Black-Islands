class_name PlayerMotor
extends Node
## Feet-origin locomotion only. No LPC, inventory or combat authority here.

@export var tuning: PlayerTuning
var actor: CharacterBody3D
var state: PlayerState
var camera: PlayerCameraRig
var terrain: VoxelTerrainAdapter
var water_motion := WaterMotion.new()
var water: WorldWater
var ready_for_play := false
var movement_locked := false
var burst_velocity := Vector3.ZERO
var external_impulse := Vector3.ZERO
var facing := Vector3.FORWARD
var running := false
var distance_travelled := 0.0
var _step_collision := KinematicCollision3D.new()

func configure(body: CharacterBody3D, stats: PlayerState, rig: PlayerCameraRig) -> void:
	actor = body
	state = stats
	camera = rig
	if tuning == null:
		tuning = PlayerTuning.new()
	actor.floor_snap_length = tuning.floor_snap
	actor.floor_max_angle = deg_to_rad(tuning.max_slope_degrees)
	actor.floor_constant_speed = true
	actor.safe_margin = 0.02
	ready_for_play = terrain == null

func tick(delta: float, axis: Vector2, run_requested: bool) -> void:
	if not ready_for_play:
		_wait_for_world()
		return
	if WorldBoundary.outside(actor.global_position):
		request_spawn(Vector3(0,30,0))
		return
	var direction := camera.planar_direction(axis)
	if movement_locked:
		direction = Vector3.ZERO
	running = run_requested and direction.length_squared() > 0.01 and state.can_consume(tuning.run_stamina_per_second * delta)
	if running:
		state.consume(tuning.run_stamina_per_second * delta)
	else:
		state.recover(delta, tuning.stamina_recovery_per_second)
	var speed := tuning.run_speed if running else tuning.walk_speed
	if camera.build_mode:
		speed *= 0.55
	if water != null and water_motion.swimming:
		speed *= float(water.motion_tuning.swim_speed)
	var desired := direction * speed
	if actor.is_on_floor() and actor.get_floor_normal().dot(Vector3.UP) > cos(actor.floor_max_angle):
		desired = direction.slide(actor.get_floor_normal()).normalized() * direction.length() * speed
	var rate := tuning.acceleration if direction.length_squared() > 0 else tuning.deceleration
	actor.velocity.x = move_toward(actor.velocity.x, desired.x, rate * delta)
	actor.velocity.z = move_toward(actor.velocity.z, desired.z, rate * delta)
	if direction.length_squared() > 0.01:
		facing = direction.normalized()
	if water != null:
		var sample := water.sample(actor.global_position)
		water_motion.apply(actor,sample,delta,water.motion_tuning)
	if water == null or not water_motion.swimming:
		actor.velocity.y = -0.2 if actor.is_on_floor() else actor.velocity.y - tuning.gravity * delta
	actor.velocity += external_impulse
	external_impulse = external_impulse.move_toward(Vector3.ZERO, tuning.deceleration * delta)
	if not burst_velocity.is_zero_approx():
		actor.velocity.x = burst_velocity.x
		actor.velocity.z = burst_velocity.z
	actor.velocity = WorldBoundary.attenuate(actor.global_position, actor.velocity)
	if terrain != null and not terrain.collision_data_ready(actor.global_position + actor.velocity * delta):
		actor.velocity.x = 0
		actor.velocity.z = 0
	_step_up(delta)
	var previous := actor.global_position
	actor.move_and_slide()
	distance_travelled += actor.global_position.distance_to(previous)

func _step_up(delta: float) -> void:
	if not actor.is_on_floor() or actor.velocity.length_squared() < 0.01:
		return
	var travel := Vector3(actor.velocity.x, 0, actor.velocity.z) * delta
	if not actor.test_move(actor.global_transform, travel, _step_collision):
		return
	if _step_collision.get_normal().y >= cos(actor.floor_max_angle):
		return
	var rise := Vector3.UP * tuning.step_height
	if actor.test_move(actor.global_transform, rise):
		return
	var elevated := actor.global_transform.translated(rise)
	if not actor.test_move(elevated, travel):
		actor.global_position.y += tuning.step_height

func _wait_for_world() -> void:
	if terrain == null:
		ready_for_play = true
		return
	var hit := terrain.surface_hit(actor.global_position.x, actor.global_position.z)
	var sample := water.sample(actor.global_position) if water != null else {}
	if sample.get("kind", "dry") != "dry":
		actor.global_position.y = sample.level + 0.03
		ready_for_play = true
	elif not hit.is_empty() and terrain.is_editable(hit.position, 2):
		actor.global_position.y = hit.position.y + 0.035
		ready_for_play = true

func request_spawn(point: Vector3) -> void:
	actor.global_position = point
	actor.velocity = Vector3.ZERO
	ready_for_play = terrain == null
	camera.reset_anchor()
