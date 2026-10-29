class_name CollisionLayers
extends RefCounted
## Physics categories; interaction volumes never act as movement blockers.
const WORLD := 1
const PLAYER := 2
const MOB := 4
const STRUCTURE := 8
const QUERY := 16
const TRIGGER := 32
const PROP := 64
const WALKABLE_BLOCKERS := WORLD|STRUCTURE|PROP
const PLAYER_MASK := WALKABLE_BLOCKERS|MOB
const MOB_MASK := WALKABLE_BLOCKERS|PLAYER|MOB
