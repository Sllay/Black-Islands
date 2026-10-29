class_name PlayerState
extends Node
## Actor-owned resource seam. Presentation subscribes; it does not own stats.

signal stamina_changed(current: float, maximum: float)
signal health_changed(current: float, maximum: float)
var max_stamina := 100.0
var current_stamina := 100.0
var max_health := 100.0
var current_health := 100.0
var defense := 0.0
var _recovery_delay := 0.0

func can_consume(amount: float) -> bool:
	return is_finite(amount) and amount >= 0 and current_stamina >= amount

func consume(amount: float) -> bool:
	if not can_consume(amount):
		return false
	if amount > 0:
		current_stamina -= amount
		_recovery_delay = 0.65
		stamina_changed.emit(current_stamina, max_stamina)
	return true

func recover(delta: float, rate: float = 18.0) -> void:
	_recovery_delay = maxf(0, _recovery_delay - delta)
	if _recovery_delay > 0 or current_stamina >= max_stamina:
		return
	current_stamina = minf(max_stamina, current_stamina + rate * delta)
	stamina_changed.emit(current_stamina, max_stamina)

func set_stamina(value: float) -> void:
	current_stamina = clampf(value,0,max_stamina)
	stamina_changed.emit(current_stamina,max_stamina)

func set_health(value: float) -> void:
	current_health = clampf(value, 0, max_health)
	health_changed.emit(current_health, max_health)
