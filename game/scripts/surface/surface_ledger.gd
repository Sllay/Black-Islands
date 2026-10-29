class_name SurfaceLedger
extends RefCounted
signal changed(domain: String, id: String)
## Authoritative deltas only; no MultiMesh transforms or presentation nodes.
const DAY := 600.0
var props: Dictionary = {}
var suppression: Dictionary = {}
var bags: Dictionary = {}
var clock := 0.0
var active_seconds := 0.0
var sequence := 0
var flags: Dictionary = {}

func new_id(prefix: String) -> String:
	sequence += 1
	return "%s:%d" % [prefix,sequence]

static func cell_key(point: Vector3) -> String:
	return "%d,%d,%d" % [floori(point.x),floori(point.y),floori(point.z)]

func suppress(point: Vector3, reason: String) -> void:
	var key := cell_key(point)
	if not suppression.has(key):
		suppression[key] = {"reasons":[],"regrow_at":0.0}
	if reason not in suppression[key].reasons:
		suppression[key].reasons.append(reason)
		changed.emit("suppression",key)

func release(point: Vector3, reason: String) -> void:
	var key := cell_key(point)
	if suppression.has(key):
		suppression[key].reasons.erase(reason)
		suppression[key].regrow_at = clock+DAY*(3.0+float(posmod(key.hash(),3000))/1000.0)
		changed.emit("suppression",key)

func suppressed(point: Vector3) -> bool:
	var row: Dictionary = suppression.get(cell_key(point),{})
	return not row.is_empty() and (not row.reasons.is_empty() or clock < float(row.regrow_at))

func snapshot() -> Dictionary:
	return {"schema_version":1,"props":props.duplicate(true),"suppression":suppression.duplicate(true),
		"bags":bags.duplicate(true),"clock":clock,"active_seconds":active_seconds,"sequence":sequence,"flags":flags.duplicate(true)}

func restore(data: Dictionary) -> Error:
	if data.get("schema_version") != 1:
		return ERR_UNAVAILABLE
	for key: String in ["props","suppression","bags"]:
		if not data.get(key) is Dictionary:
			return ERR_INVALID_DATA
	props = data.props.duplicate(true)
	suppression = data.suppression.duplicate(true)
	bags = data.bags.duplicate(true)
	clock = float(data.get("clock",0))
	active_seconds = float(data.get("active_seconds",0))
	sequence = int(data.get("sequence",0))
	flags = data.get("flags",{}).duplicate(true)
	return OK
