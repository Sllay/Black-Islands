class_name GrassGeometry
extends RefCounted
## A cluster is one native instance. Sizes are voxel-local (terrain scale0.5).
static var meshes: Dictionary = {}
static var texture: ImageTexture
static func cluster(cards: int) -> ArrayMesh:
	if meshes.has(cards):
		return meshes[cards]
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for card: int in cards:
		var direction := Vector3(cos(PI*card/cards),0,sin(PI*card/cards))*1.25
		var corners := [-direction,direction,direction+Vector3.UP*1.3,-direction+Vector3.UP*1.3]
		var uv := [Vector2(0,1),Vector2(1,1),Vector2(1,0),Vector2(0,0)]
		for index: int in [0,2,1,0,3,2]:
			surface.set_uv(uv[index])
			surface.set_normal(Vector3.UP)
			surface.add_vertex(corners[index])
	meshes[cards] = surface.commit()
	return meshes[cards]
static func blade_texture() -> ImageTexture:
	if texture != null:
		return texture
	# No grass texture exists in the shipped catalog. Project-authored cutout,
	# generated once and cached, not per instance/frame; no external license.
	var image := Image.create(128,64,false,Image.FORMAT_RGBA8)
	for y: int in 64:
		for x: int in 128:
			var alpha := 0.0
			var height := 1.0-y/63.0
			for blade: int in 7:
				var tip := .52+.44*absf(sin(blade*5.31))
				var center := 9.0+blade*18+sin(blade*3.7)*height*13
				var width := (1.0-height/tip)*5.5
				if height < tip and absf(x-center) < width:
					alpha = 1
			image.set_pixel(x,y,Color(.36+.15*height,.57+.16*height,.19+.12*height,alpha))
	image.fix_alpha_edges()
	image.generate_mipmaps()
	# Preserve cutout coverage across mips: scale alpha to retain base coverage.
	var bytes := image.get_data()
	var base_coverage := 0.0
	for offset: int in range(3,128*64*4,4):
		base_coverage += float(bytes[offset] >= 128)/(128*64)
	for mip: int in range(1,image.get_mipmap_count()+1):
		var first := image.get_mipmap_offset(mip)
		var pixels := maxi(1,128>>mip)*maxi(1,64>>mip)
		var low := 0.0
		var high := 8.0
		for iteration: int in 10:
			var scale := (low+high)*.5
			var coverage := 0.0
			for pixel: int in pixels:
				coverage += float(bytes[first+pixel*4+3]*scale >= 128)/pixels
			if coverage < base_coverage:
				low = scale
			else:
				high = scale
		for pixel: int in pixels:
			var offset := first+pixel*4+3
			bytes[offset] = mini(255,int(bytes[offset]*high))
	image.set_data(128,64,true,Image.FORMAT_RGBA8,bytes)
	texture = ImageTexture.create_from_image(image)
	return texture
