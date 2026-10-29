class_name WorldPreview
extends Node
## Fixed world-only render. UI has no canvas in this viewport; actors are hidden.
const SIZE := Vector2i(640,360)
var session: WorldSession
var captured := false

func capture() -> Error:
	if captured or not session.pawn.spawned:
		return ERR_UNAVAILABLE
	var viewport := SubViewport.new()
	viewport.size = SIZE
	viewport.world_3d = session.get_world_3d()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	var camera := Camera3D.new()
	camera.cull_mask = 1
	viewport.add_child(camera)
	var source: Camera3D = session.pawn.camera_rig.camera
	camera.global_transform = source.global_transform
	camera.projection = source.projection
	camera.fov = source.fov
	camera.size = source.size
	var visual := session.pawn.visual
	var prior := visual.visible
	visual.visible = false
	var mob_visibility := session.surface.mobs.visible
	session.surface.mobs.visible = false
	await RenderingServer.frame_post_draw
	var image := viewport.get_texture().get_image()
	visual.visible = prior
	session.surface.mobs.visible = mob_visibility
	viewport.queue_free()
	if image == null or image.get_size() != SIZE:
		return ERR_CANT_CREATE
	var directory := Profiles.library.world_directory(Profiles.current_profile())
	DirAccess.make_dir_recursive_absolute(directory)
	var error := image.save_jpg(directory.path_join("preview.jpg.tmp"),.78)
	if error == OK:
		error = DirAccess.rename_absolute(directory.path_join("preview.jpg.tmp"),directory.path_join("preview.jpg"))
	captured = error == OK
	return error
