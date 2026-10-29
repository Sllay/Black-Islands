class_name MobBehaviorState
extends LimboState
## Reusable HSM task: publishes intent, never touches a physics body.
var intent_id: String

func _enter() -> void:
	agent.publish(intent_id)

func _update(_delta: float) -> void:
	agent.decide()
