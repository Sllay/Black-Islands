class_name CraftStation
extends RefCounted
## Stable world record adapter; no autonomous station queue in Chapter1.
var id := ""
var world_id := ""
var tags: Array = ["workbench"]
var radius := 12.0
static func available(registry: ContainerService, station_id: String) -> bool:
	return registry != null and registry.records.has(station_id) and registry.records[station_id].kind == "Workbench" and registry.inventories.has(station_id)
