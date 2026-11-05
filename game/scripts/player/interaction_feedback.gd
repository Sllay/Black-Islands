class_name InteractionFeedback
extends RefCounted
## Presentation policy consumes the sole targeter and production placement rules.
enum State { DEFAULT, INTERACTABLE, COMBAT_TARGET, BUILD_VALID, BUILD_INVALID, OUT_OF_RANGE }
static func precision(actor: PlayerActor) -> bool:
	return actor.camera_rig.build_mode or actor.camera_rig.gameplay_mode == PlayerCameraRig.GameplayMode.SHOULDER or (actor.combat.weapon != null and actor.combat.weapon.weapon_class == "Bow")
static func resolve(actor: PlayerActor, surface: SurfaceRuntime = null) -> State:
	var target := actor.targeter.current
	if actor.targeter.aim_out_of_range and target.kind == TargetResult.Kind.NONE: return State.OUT_OF_RANGE
	if actor.camera_rig.build_mode:
		return State.BUILD_VALID if surface != null and surface.actions.preview(target) == OK else State.BUILD_INVALID
	if target.kind == TargetResult.Kind.COMBAT_TARGET: return State.COMBAT_TARGET
	if not target.available_actions.is_empty(): return State.INTERACTABLE
	return State.DEFAULT
