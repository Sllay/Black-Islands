class_name WeaponVisualRig
extends Node3D
## One reusable rig. Body remains foot-anchored LPC; only horizontal camera yaw.
var profile: WeaponVisualProfile
var sprite: Sprite3D
var trail: MeshInstance3D
var trail_mesh: QuadMesh
var _selected := false
var _trail_remaining := 0.0
var trail_profile: WeaponTrailProfile
var _material: StandardMaterial3D
var _textures: Dictionary = {}
var layer := "FRONT_CHARACTER"
var phase := "idle"
func _ready() -> void:
	sprite = Sprite3D.new()
	sprite.name = "DetachedWeapon"
	sprite.pixel_size = .03125
	sprite.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	sprite.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	sprite.no_depth_test = false
	add_child(sprite)
	trail = MeshInstance3D.new()
	trail.name = "WeaponTrail"
	trail_mesh = QuadMesh.new()
	trail.mesh = trail_mesh
	trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_material = StandardMaterial3D.new()
	_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	trail.material_override = _material
	add_child(trail)
	select(null)
func select(next: WeaponVisualProfile) -> void:
	if _selected and profile == next: return
	_selected = true
	profile = next
	_textures.clear()
	trail.visible = false
	sprite.visible = next != null and next.mode == "DETACHED_SPRITE"
	if not sprite.visible:
		sprite.texture = null
		return
	for key: String in ["idle_texture","attack_texture"]:
		var path: String = next.data.get(key,"")
		if not path.is_empty(): _textures[key] = load(path)
	trail_profile = WeaponTrailProfile.new(next.data.get("trail_profile",{}))
	_material.albedo_color = trail_profile.color
func tick(direction: int, heading: float, next_phase: String, progress: float, delta: float = 1.0/60) -> void:
	phase = next_phase
	if profile == null or profile.mode != "DETACHED_SPRITE": return
	rotation.y = heading
	var key: String = ["north","west","south","east"][direction]
	var offset: Array = profile.data.get("direction_offsets",{}).get(key,[.55,.85])
	var position_offset := profile.sample("position_curve",progress,0) if phase != "idle" else 0.0
	var size := profile.sample("scale_curve",progress,1) if phase != "idle" else 1.0
	layer = str(profile.data.get("layer_behavior",{}).get(key,"FRONT_CHARACTER"))
	if phase == "attack": layer = str(profile.data.get("attack_layer",layer))
	sprite.position = Vector3(float(offset[0])+position_offset,float(offset[1]),.06 if layer == "FRONT_CHARACTER" else -.06)
	sprite.render_priority = 1 if layer == "FRONT_CHARACTER" else -1
	sprite.scale = Vector3.ONE*size
	sprite.rotation.z = deg_to_rad(profile.sample("rotation_curve",progress,0)) if phase != "idle" else 0.0
	sprite.offset = Vector2(profile.data.get("pivot",[16,16])[0],profile.data.get("pivot",[16,16])[1])-Vector2(16,16)
	sprite.texture = _textures.get("attack_texture" if phase == "attack" else "idle_texture")
	_trail_remaining = trail_profile.duration if phase == "attack" else maxf(0,_trail_remaining-delta)
	trail.visible = trail_profile.enabled and _trail_remaining > 0
	trail.position = sprite.position+Vector3(-.35,0,-.01)
	trail.rotation.z = sprite.rotation.z-.5
	trail_mesh.size = Vector2(.85,trail_profile.width)
func report() -> Dictionary:
	return {"mode":profile.mode if profile != null else "NONE","visible":sprite.visible,"layer":layer,"phase":phase,"position":sprite.position,"rotation":sprite.rotation.z,"trail":trail.visible,"nodes":get_child_count()}
