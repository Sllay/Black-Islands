class_name LPCPortrait
extends TextureRect
## The same composed catalog appearance as Sprite3D; bounded UI frame crop.
func present(config: Dictionary) -> void:
	custom_minimum_size = Vector2(100,96)
	expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var composed := LPCCompositionCache.obtain(config)
	if composed == null:
		return
	var clip: Dictionary = composed.clips.MOVE
	var atlas := AtlasTexture.new()
	atlas.atlas = clip.texture
	atlas.region = Rect2(0,int(clip.frame_size)*2,int(clip.frame_size),int(clip.frame_size))
	texture = atlas
