class_name WorldCoordinates
extends RefCounted

const VOXEL_SIZE := 0.5
const BUILD_CELL := 1.0
const CHUNK_SIZE := 64.0
const VOXELS_PER_CHUNK := 128

static func world_to_voxel(position: Vector3) -> Vector3i:
	return Vector3i((position / VOXEL_SIZE).floor())

static func voxel_to_world(position: Vector3i) -> Vector3:
	return Vector3(position) * VOXEL_SIZE

static func world_to_chunk(position: Vector3) -> Vector3i:
	return Vector3i((position / CHUNK_SIZE).floor())

static func voxel_to_chunk(position: Vector3i) -> Vector3i:
	return Vector3i((Vector3(position) / VOXELS_PER_CHUNK).floor())

static func world_to_cell(position: Vector3) -> Vector3i:
	return Vector3i((position / BUILD_CELL).floor())

static func voxel_to_cell(position: Vector3i) -> Vector3i:
	return world_to_cell(voxel_to_world(position))

static func chunk_origin(position: Vector3i) -> Vector3:
	return Vector3(position) * CHUNK_SIZE
