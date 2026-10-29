class_name TerrainEditService
extends RefCounted
## Intent -> residency validation -> bounded native operation -> durable sparse
## delta -> committed notification. UI never owns terrain/save truth.

signal terrain_changed(area: AABB)
var terrain: VoxelTerrainAdapter
var store: WorldDeltaStore
var last_result: Dictionary = {}

func apply(center: Vector3, radius: float, paint: bool = false, material: int = 2) -> Error:
	if terrain == null or store == null or radius > 4.0 or not terrain.is_editable(center, radius):
		return ERR_BUSY
	var started := Time.get_ticks_msec()
	var low := WorldCoordinates.world_to_voxel(center - Vector3.ONE * radius) - Vector3i.ONE * 2
	var high := WorldCoordinates.world_to_voxel(center + Vector3.ONE * radius) + Vector3i.ONE * 3
	var before := terrain.capture_samples(low, high - low)
	var accepted := terrain.paint_sphere(center, radius, material) if paint else terrain.dig_sphere(center, radius)
	if not accepted:
		return ERR_BUSY
	var after := terrain.capture_samples(low, high - low)
	var changes: Dictionary = {}
	for voxel: Vector3i in after:
		if after[voxel] != before[voxel]:
			changes[voxel] = after[voxel]
	var error := store.commit(changes)
	if error != OK:
		terrain.restore_samples(low, high - low, before)
		last_result = {"error": error, "rolled_back": true}
		return error
	var area := AABB(WorldCoordinates.voxel_to_world(low), Vector3(high - low) * WorldCoordinates.VOXEL_SIZE)
	last_result = {"error": OK, "changed_voxels": changes.size(), "commit_ms": Time.get_ticks_msec() - started,
		"started_ms": started, "paint": paint, "area": area, "center": center}
	terrain_changed.emit(area)
	return OK
