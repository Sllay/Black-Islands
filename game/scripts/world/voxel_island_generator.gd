class_name VoxelIslandGenerator
extends VoxelGeneratorScript
## Legacy QA compatibility only. Production terrain uses the graph directly.

var field: IslandField = IslandField.new():
	set(value):
		field = value
		_configure_base()
var _base: VoxelGeneratorGraph

func _init() -> void:
	_configure_base()

func _configure_base() -> void:
	if field is WorldFieldV2:
		_base = field.graph
	else:
		var builder := NativeTerrainGraph.new()
		var result := builder.build_legacy(field)
		assert(result.success,str(result))
		_base = builder.generator

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
	_base.generate_block(buffer,origin,lod)
