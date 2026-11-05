class_name InteractionCrosshair
extends Control
## One lightweight overlay; no query or input ownership.
var actor: PlayerActor
var feedback := InteractionFeedback.State.DEFAULT
var point := Vector2.ZERO
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	actor = get_parent().get_parent() as PlayerActor
func _process(_delta: float) -> void:
	if actor == null: return
	visible = not actor.inventory.is_open and InteractionFeedback.precision(actor)
	if not visible: return
	var next_point := actor.camera_rig.aim_screen*size
	var next_feedback := actor.targeter.feedback
	if next_point != point or next_feedback != feedback:
		point = next_point
		feedback = next_feedback
		queue_redraw()
func _draw() -> void:
	var color: Color = [Color("f3e9d1"),Color("7ee2c4"),Color("ff947c"),Color("8dde83"),Color("fa6d68"),Color("b9a99b")][feedback]
	draw_arc(point,8,0,TAU,20,Color(0,0,0,.7),4,true)
	draw_arc(point,8,0,TAU,20,color,1.8,true)
	if feedback == InteractionFeedback.State.BUILD_INVALID or feedback == InteractionFeedback.State.OUT_OF_RANGE:
		draw_line(point-Vector2(4,4),point+Vector2(4,4),color,2,true)
		draw_line(point+Vector2(-4,4),point+Vector2(4,-4),color,2,true)
	elif feedback == InteractionFeedback.State.COMBAT_TARGET:
		for axis: Vector2 in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT]: draw_line(point+axis*11,point+axis*16,color,2,true)
	elif feedback in [InteractionFeedback.State.BUILD_VALID,InteractionFeedback.State.INTERACTABLE]:
		draw_circle(point,2.5,color)
