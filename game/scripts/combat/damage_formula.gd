class_name DamageFormula
extends RefCounted

static func taken(raw_damage: float, defense: float) -> float:
	if not is_finite(raw_damage) or not is_finite(defense):
		return 0.0
	return maxf(raw_damage,0.0) * 100.0 / (100.0 + maxf(defense,0.0))
