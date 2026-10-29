class_name InteractionTargeter
extends Node
## Sole acquisition authority: camera ray + bounded nearby actor query.
## Melee hit volumes are attack execution, not independent aiming raycasts.

signal target_changed(result: TargetResult)
@export var maximum_distance := 6.0
@export var priorities := {"COMBAT_TARGET": 40, "INTERACTABLE": 30, "BUILD_GRID": 20, "TERRAIN": 10}
var current := TargetResult.new()
var actor: CharacterBody3D
var rig: PlayerCameraRig
var probes := 0
var _elapsed := 0.0
var _ray := PhysicsRayQueryParameters3D.new()
var _near := PhysicsShapeQueryParameters3D.new()

func configure(body: CharacterBody3D, camera_rig: PlayerCameraRig) -> void:
	actor = body
	rig = camera_rig
	_ray.collision_mask = 1 | 4 | 8 | 16
	_ray.collide_with_areas = true
	_ray.exclude = [actor.get_rid()]
	var shape := SphereShape3D.new()
	shape.radius = 2.5
	_near.shape = shape
	_near.collision_mask = 4 | 8 | 16
	_near.collide_with_areas = true
	_near.exclude = [actor.get_rid()]

func tick(delta: float, facing: Vector3) -> void:
	_elapsed += delta
	if _elapsed < 0.1:
		return
	_elapsed = 0
	probe(facing)

func probe(facing: Vector3) -> TargetResult:
	var previous_kind := current.kind
	var previous_entity: Node3D = current.entity if is_instance_valid(current.entity) else null
	current.clear()
	probes += 1
	var screen := rig.aim_screen * actor.get_viewport().get_visible_rect().size
	_ray.from = rig.camera.project_ray_origin(screen)
	_ray.to = _ray.from + rig.camera.project_ray_normal(screen) * 100.0
	var space := actor.get_world_3d().direct_space_state
	var hit := space.intersect_ray(_ray)
	if not hit.is_empty() and actor.global_position.distance_to(hit.position) <= maximum_distance:
		_set_hit(hit.collider, hit.position, hit.normal)
	if not rig.build_mode:
		_near.transform = Transform3D(Basis.IDENTITY, actor.global_position + Vector3.UP * 0.8 + facing)
		for candidate: Dictionary in space.intersect_shape(_near, 8):
			var entity: Node3D = candidate.collider
			var point := entity.global_position
			var direction := point - actor.global_position
			if direction.length() > maximum_distance or direction.normalized().dot(facing) < 0.1:
				continue
			if not has_line_of_sight(point):
				continue
			var kind := _kind(entity)
			if _priority(kind) > _priority(current.kind):
				_set_hit(entity, point, Vector3.UP)
	if current.kind != previous_kind or current.entity != previous_entity:
		target_changed.emit(current)
	return current

func _kind(entity: Node3D) -> TargetResult.Kind:
	if entity.is_in_group("combat_targets"):
		return TargetResult.Kind.COMBAT_TARGET
	if entity.is_in_group("build_surfaces"):
		return TargetResult.Kind.BUILD_GRID
	if entity.is_in_group("interactables"):
		return TargetResult.Kind.INTERACTABLE
	return TargetResult.Kind.BUILD_GRID if rig.build_mode else TargetResult.Kind.TERRAIN

func _priority(kind: TargetResult.Kind) -> int:
	return int(priorities.get(TargetResult.Kind.keys()[kind], 0))

func has_line_of_sight(point: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(actor.global_position + Vector3.UP * 0.8, point + Vector3.UP * 0.8, 1)
	return actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _set_hit(entity: Node3D, point: Vector3, surface_normal: Vector3) -> void:
	current.kind = _kind(entity)
	current.entity = entity
	current.world_position = point
	current.normal = surface_normal
	current.distance = actor.global_position.distance_to(point)
	current.voxel = WorldCoordinates.world_to_voxel(point)
	current.build_cell = WorldCoordinates.world_to_cell(point)
	current.build_edge = BuildGrid.shared_edge(current.build_cell, current.build_cell + Vector3i.RIGHT)

func interact() -> bool:
	if is_instance_valid(current.entity) and current.entity.has_method("interact"):
		current.entity.call("interact", actor)
		return true
	return false
