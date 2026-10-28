extends SceneTree

func _initialize() -> void:
	for entry: Array in [[Vector3(-0.01, -64.01, 64), Vector3i(-1,-2,1)], [Vector3(64,64,0), Vector3i(1,1,0)], [Vector3(-64,-64,-64), Vector3i(-1,-1,-1)]]:
		if WorldCoordinates.world_to_chunk(entry[0]) != entry[1]:
			push_error("WorldChunk signed/vertical boundary failed")
			quit(1)
			return
	for voxel: Vector3i in [Vector3i(-129,-1,128), Vector3i(0,127,128), Vector3i(129,256,-128)]:
		var world := WorldCoordinates.voxel_to_world(voxel)
		if WorldCoordinates.world_to_voxel(world) != voxel or WorldCoordinates.voxel_to_chunk(voxel) != WorldCoordinates.world_to_chunk(world):
			quit(1)
			return
	if WorldCoordinates.voxel_to_cell(Vector3i(-1,2,3)) != Vector3i(-1,1,1):
		quit(1)
		return
	print("WORLD_COORDINATES PASS voxel=0.5 cell=1 chunk=64 signed+vertical")
	quit()
