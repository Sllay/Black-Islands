class_name VoxelDeltaStream
extends VoxelStreamScript
## Sparse project-owned deltas layered over the actual native graph.
## No per-voxel base loop and no generator wrapper: series queries remain native.
var base: VoxelGeneratorGraph
var deltas: WorldDeltaStore

func _get_used_channels_mask() -> int:
	return NativeTerrainGraph.CHANNELS

func _load_voxel_block(buffer: VoxelBuffer, block: Vector3i, lod: int) -> int:
	if deltas == null:
		return VoxelStream.RESULT_BLOCK_NOT_FOUND
	var step := 1<<lod
	var origin := block*buffer.get_size()*step
	var changes := deltas.snapshot_box(origin,buffer.get_size()*step)
	if changes.is_empty():
		return VoxelStream.RESULT_BLOCK_NOT_FOUND
	base.generate_block(buffer,origin,lod)
	for voxel: Vector3i in changes:
		var relative := voxel-origin
		if relative%step != Vector3i.ZERO:
			continue
		@warning_ignore("integer_division")
		var cell := relative/step
		var row: Dictionary = changes[voxel]
		buffer.set_voxel(int(row.density)&0xffff,cell.x,cell.y,cell.z,VoxelBuffer.CHANNEL_SDF)
		buffer.set_voxel(0x3210,cell.x,cell.y,cell.z,VoxelBuffer.CHANNEL_INDICES)
		var weights := 0
		for index: int in 4:
			weights |= int(row.materials[index])<<(index*4)
		buffer.set_voxel(weights,cell.x,cell.y,cell.z,VoxelBuffer.CHANNEL_WEIGHTS)
	return VoxelStream.RESULT_BLOCK_FOUND

func _save_voxel_block(_buffer: VoxelBuffer, _block: Vector3i, _lod: int) -> void:
	# Edit service already captured authoritative sparse changes. Native caches,
	# meshes and dense generated buffers are never a second durable save owner.
	pass
