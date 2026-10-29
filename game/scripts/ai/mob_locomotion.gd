class_name MobLocomotion
extends RefCounted
## Intent -> cached obstacle/ground steering -> ACTIVE physics adapter.
## Chapter1 local probes; replaceable by region navigation/local avoidance later.
var body: CharacterBody3D
var terrain: VoxelTerrainAdapter
var speed: float
var _poll := 0.0
var _steering := Vector3.ZERO
var probes := 0

func configure(actor: CharacterBody3D, world: VoxelTerrainAdapter, maximum_speed: float) -> void:
	body = actor
	terrain = world
	speed = maximum_speed

func tick(delta: float, desired: Vector3, locked: bool) -> void:
	_poll -= delta
	if locked or desired.is_zero_approx():
		_steering = Vector3.ZERO
		_poll = 0
	elif _poll <= 0:
		_poll = .2
		_steering = steer(desired)
	body.velocity.x = move_toward(body.velocity.x,_steering.x*speed,12*delta)
	body.velocity.z = move_toward(body.velocity.z,_steering.z*speed,12*delta)
	body.velocity.y = -.2 if body.is_on_floor() else body.velocity.y-18*delta
	if not terrain.collision_data_ready(body.global_position+body.velocity*delta):
		body.velocity.x = 0
		body.velocity.z = 0
	body.move_and_slide()

func steer(desired: Vector3) -> Vector3:
	var space := body.get_world_3d().direct_space_state
	for angle: float in [0.0,PI/4,-PI/4,PI/2,-PI/2]:
		var direction := desired.normalized().rotated(Vector3.UP,angle)
		var origin := body.global_position+Vector3.UP*.5
		var ray := PhysicsRayQueryParameters3D.create(origin,origin+direction*1.2,CollisionLayers.MOB_MASK)
		ray.exclude = [body.get_rid()]
		probes += 1
		if not space.intersect_ray(ray).is_empty():
			continue
		var ahead := body.global_position+direction*.9
		ray.from = ahead+Vector3.UP*.7
		ray.to = ahead-Vector3.UP*1.3
		ray.collision_mask = CollisionLayers.WALKABLE_BLOCKERS
		probes += 1
		var floor_hit := space.intersect_ray(ray)
		if not floor_hit.is_empty() and floor_hit.normal.y > .6:
			return direction*minf(1,desired.length())
	return Vector3.ZERO
