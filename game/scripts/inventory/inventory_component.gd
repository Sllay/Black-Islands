class_name InventoryComponent
extends Node

signal open_changed(open: bool)
var state := InventoryState.new()
var is_open := false
var simulation: InventorySimulation

func _ready() -> void:
	for entry: Array in [["bi.weapon.starter_sword",1],["bi.tool.stone_pick",1],["bi.food.coconut",5],["bi.build.foundation",3],["bi.resource.stone",300],["bi.ammo.arrow",18],["bi.armor.fiber_hat",1],["bi.armor.fiber_chest",1],["bi.armor.fiber_legs",1],["bi.accessory.shell_charm",2]]:
		state.add_item(entry[0], entry[1])
	simulation = InventorySimulation.new()
	simulation.name = "InventorySimulation"
	simulation.register(state)
	add_child(simulation)
	for index: int in range(4):
		state.assign_hotbar(index, index)

func toggle() -> void:
	is_open = not is_open
	open_changed.emit(is_open)
