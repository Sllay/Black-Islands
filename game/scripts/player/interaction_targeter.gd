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
	_ray.collision_mask = CollisionLayers.WORLD|CollisionLayers.QUERY|CollisionLayers.MOB|CollisionLayers.STRUCTURE|CollisionLayers.PROP
	_ray.collide_with_areas = true
	_ray.exclude = [actor.get_rid()]
	var shape := SphereShape3D.new()
	shape.radius = 2.5
	_near.shape = shape
	_near.collision_mask = CollisionLayers.QUERY|CollisionLayers.MOB
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
	var previous_actions := current.available_actions.duplicate()
	current.clear()
	probes += 1
	var screen := rig.aim_screen*actor.get_viewport().get_visible_rect().size
	_ray.from = rig.camera.project_ray_origin(screen)
	_ray.to = _ray.from+rig.camera.project_ray_normal(screen)*100.0
	var space := actor.get_world_3d().direct_space_state
	var hit := space.intersect_ray(_ray)
	if not hit.is_empty() and actor.global_position.distance_to(hit.position) <= maximum_distance:
		_set_hit(_subject(hit.collider),hit.position,hit.normal)
	if not rig.build_mode:
		_near.transform = Transform3D(Basis.IDENTITY,actor.global_position+Vector3.UP*.8+facing)
		for candidate: Dictionary in space.intersect_shape(_near,16):
			var entity := _subject(candidate.collider)
			var point := entity.global_position
			var direction := point-actor.global_position
			if direction.length() > maximum_distance or direction.normalized().dot(facing) < .1 or not has_line_of_sight(point,entity):
				continue
			if _priority(_kind(entity)) > _priority(current.kind):
				_set_hit(entity,point,Vector3.UP)
	if current.kind != previous_kind or current.entity != previous_entity or previous_actions != current.available_actions:
		target_changed.emit(current)
	return current

func _subject(entity: Node3D) -> Node3D:
	if entity is InteractionVolume and is_instance_valid(entity.subject):
		return entity.subject
	if entity.get_parent() is SurfaceObject:
		return entity.get_parent()
	return entity

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

func has_line_of_sight(point: Vector3, target: Node3D = null) -> bool:
	var query := PhysicsRayQueryParameters3D.create(actor.global_position+Vector3.UP*.8,point+Vector3.UP*.8,CollisionLayers.WALKABLE_BLOCKERS)
	var excluded: Array[RID] = [actor.get_rid()]
	if target is CollisionObject3D:
		excluded.append(target.get_rid())
	elif target is SurfaceObject and target.has_node("Blocker"):
		excluded.append(target.get_node("Blocker").get_rid())
	query.exclude = excluded
	return actor.get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func _set_hit(entity: Node3D, point: Vector3, surface_normal: Vector3) -> void:
	current.kind = _kind(entity)
	current.entity = entity
	current.world_position = point
	current.normal = surface_normal
	current.distance = actor.global_position.distance_to(point)
	current.voxel = WorldCoordinates.world_to_voxel(point)
	current.build_cell = WorldCoordinates.world_to_cell(point)
	current.build_edge = BuildGrid.shared_edge(current.build_cell,current.build_cell+Vector3i.RIGHT)
	current.available_actions.clear()
	if actor is PlayerActor and actor.water != null:
		var held: ItemDefinition = actor.inventory.state.active_definition()
		if held != null and held.id == "bi.tool.watering_can" and actor.water.sample(point).kind in ["lake","river"] and current.distance <= 4:
			current.available_actions.append(&"refill")
	if entity.has_method("available_actions"):
		for id: String in entity.call("available_actions",actor):
			current.available_actions.append(StringName(id))
	elif rig.build_mode and actor is PlayerActor:
		var item: ItemDefinition = actor.inventory.state.active_definition()
		if item != null and item.category == "BUILDING_PIECE" and surface_normal.y > .7:
			current.available_actions.append(&"build")

func interact() -> bool:
	if &"refill" in current.available_actions:
		return WaterContainer.refill(actor.inventory.state,actor.inventory.state.hotbar_at(actor.inventory.state.selected).stack_uid,actor.water,current.world_position,actor.global_position) == OK
	if current.available_actions.is_empty():
		return false
	if is_instance_valid(current.entity) and current.entity.has_method("interact"):
		current.entity.call("interact",actor)
		return true
	if &"build" in current.available_actions:
		var surface := get_tree().get_first_node_in_group("surface_runtime")
		if surface != null:
			surface.primary_action()
			return true
	return false
