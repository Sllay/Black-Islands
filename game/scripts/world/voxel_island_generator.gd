class_name VoxelIslandGenerator
extends VoxelGeneratorScript
## Native Voxel Tools schedules these pure-data callbacks off the main thread.

var field := IslandField.new()

var deltas: WorldDeltaStore

func _get_used_channels_mask() -> int:
	return (1 << VoxelBuffer.CHANNEL_SDF) | (1 << VoxelBuffer.CHANNEL_INDICES) | (1 << VoxelBuffer.CHANNEL_WEIGHTS)

func _generate_block(buffer: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	# Preserve the native SDF16 format; no SceneTree access from worker jobs.
	_fill_base(buffer, origin, lod)
	if deltas != null:
		var step := 1 << lod
		var patches := deltas.snapshot_box(origin, buffer.get_size() * step)
		for voxel: Vector3i in patches:
			var relative := voxel - origin
			if relative % step != Vector3i.ZERO:
				continue
			@warning_ignore("integer_division") # Aligned nearest-neighbor native LOD sample.
			var cell := relative / step
			var sample: Dictionary = patches[voxel]
			buffer.set_voxel(int(sample.density) & 0xffff, cell.x, cell.y, cell.z, VoxelBuffer.CHANNEL_SDF)
			buffer.set_voxel(0x3210, cell.x, cell.y, cell.z, VoxelBuffer.CHANNEL_INDICES)
			var weights := 0
			for index: int in range(4):
				weights |= int(sample.materials[index]) << (index * 4)
			buffer.set_voxel(weights, cell.x, cell.y, cell.z, VoxelBuffer.CHANNEL_WEIGHTS)
	buffer.compress_uniform_channels()

func _fill_base(buffer: VoxelBuffer, origin: Vector3i, lod: int) -> void:
	buffer.fill(0x3210, VoxelBuffer.CHANNEL_INDICES)
	var size := buffer.get_size()
	var step := 1 << lod
	var low := Vector3(origin) * WorldCoordinates.VOXEL_SIZE
	var high := Vector3(origin + (size - Vector3i.ONE) * step) * WorldCoordinates.VOXEL_SIZE
	var a := Vector3(low.x / field.radius.x, (low.y + 35.0) / 65.0, low.z / field.radius.y)
	var b := Vector3(high.x / field.radius.x, (high.y + 35.0) / 65.0, high.z / field.radius.y)
	var nearest := Vector3(clampf(0, a.x, b.x), clampf(0, a.y, b.y), clampf(0, a.z, b.z))
	var farthest := Vector3(maxf(absf(a.x), absf(b.x)), maxf(absf(a.y), absf(b.y)), maxf(absf(a.z), absf(b.z)))
	# Identical +/-4m field samples at every LOD, including uniform shortcuts.
	if low.y > 34.0 or nearest.length() > 1.08:
		buffer.fill_f(8.0, VoxelBuffer.CHANNEL_SDF)
		buffer.fill(0xf000, VoxelBuffer.CHANNEL_WEIGHTS)
		return
	if high.y < -22.0 and farthest.length() < 0.92:
		buffer.fill_f(-8.0, VoxelBuffer.CHANNEL_SDF)
		buffer.fill(0xf000, VoxelBuffer.CHANNEL_WEIGHTS)
		return
	for z: int in range(size.z):
		for x: int in range(size.x):
			var wx := float(origin.x + x * step) * WorldCoordinates.VOXEL_SIZE
			var wz := float(origin.z + z * step) * WorldCoordinates.VOXEL_SIZE
			var height := field.surface_height(wx, wz)
			var horizontal := wx * wx / (field.radius.x * field.radius.x) + wz * wz / (field.radius.y * field.radius.y)
			var surface := minf(height, -35.0 + 65.0 * sqrt(1.0 - horizontal)) if horizontal <= 1.0 else height
			for y: int in range(size.y):
				var wy := float(origin.y + y * step) * WorldCoordinates.VOXEL_SIZE
				var vertical := (wy + 35.0) / 65.0
				var sdf := maxf((sqrt(horizontal + vertical * vertical) - 1.0) * 50.0, wy - height)
				buffer.set_voxel_f(clampf(sdf / WorldCoordinates.VOXEL_SIZE, -8.0, 8.0), x, y, z, VoxelBuffer.CHANNEL_SDF)
				var material := field.material_for(wy, surface)
				buffer.set_voxel(15 << (material * 4), x, y, z, VoxelBuffer.CHANNEL_WEIGHTS)
