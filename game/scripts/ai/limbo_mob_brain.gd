class_name LimboMobBrain
extends Node
## ACTIVE behavior adapter. MobDomain owns state; native LimboAI owns transitions.
const STATES := ["IDLE","WANDER","FLEE","WARN_ATTACK","CHASE","ATTACK","SLEEP","STASIS"]
var machine: LimboHSM
var definition: Dictionary
var state: Dictionary
var context: Dictionary = {}
var command := {"kind":"IDLE","target":Vector3.ZERO}
var target := Vector3.ZERO

func configure(data: Dictionary, authoritative: Dictionary) -> void:
	definition = data
	state = authoritative
	machine = LimboHSM.new()
	machine.name = "BehaviorHSM"
	machine.update_mode = LimboHSM.MANUAL
	add_child(machine)
	for id: String in STATES:
		var task := MobBehaviorState.new()
		task.name = id
		task.intent_id = id
		machine.add_child(task)
		machine.add_transition(machine.ANYSTATE,task,StringName(id))
	machine.initial_state = machine.get_node("IDLE")
	machine.initialize(self)
	machine.set_active(true)

func tick(perception: Dictionary, goal: Vector3) -> void:
	context = perception
	target = goal
	machine.update(.25)

func decide() -> void:
	var selected := MobBrain.choose(definition,context)
	if selected == "WARN_ATTACK":
		if float(state.warning_since) < 0:
			state.warning_since = float(context.get("clock",0))
		if float(context.get("clock",0))-float(state.warning_since) >= float(definition.warning):
			selected = "ATTACK"
	else:
		state.warning_since = -1.0
	if selected == "ATTACK" and float(context.get("distance",INF)) >= 1.8:
		selected = "CHASE"
	if selected not in STATES:
		selected = "IDLE"
	if str(machine.get_active_state().name) != selected:
		machine.dispatch(StringName(selected))
	else:
		publish(selected)

func publish(id: String) -> void:
	state.intent = id
	command = {"kind":id,"target":target}

func deactivate() -> void:
	if machine != null:
		machine.dispatch(&"STASIS")
		machine.set_active(false)

func report() -> Dictionary:
	return {"executor":"LimboAI 1.8.1 HSM","state":str(machine.get_active_state().name),"intent":command.kind}
