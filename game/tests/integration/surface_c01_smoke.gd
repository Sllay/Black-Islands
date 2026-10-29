extends Node
var failures := 0
func _ready() -> void:
	var props := PropField.new(IslandField.new(424242))
	var one := props.candidates(Vector2i(1,0))
	_check(one == props.candidates(Vector2i(1,0)),"deterministic candidates")
	_check(one != PropField.new(IslandField.new(123)).candidates(Vector2i(1,0)),"different seed")
	for pair: Array in [[Vector3(205,2,0),"BEACH"],[Vector3(0,12,0),"TROPICAL_PLAINS"],[Vector3(150,20,0),"TROPICAL_HILLS"],[Vector3(60,12,0),"CENTRAL_FOREST"]]:
		_check(props.biome(pair[0]) == pair[1],"biome "+str(pair[1]))
	var tree := HarvestService.create("tree")
	tree.health = 3
	var axe: Dictionary = SurfaceCatalog.data().tools["bi.tool.axe"].duplicate(true)
	axe.power = 500
	var overkill := HarvestService.strike(tree,axe,0,"overkill")
	_check(overkill.actual_damage == 3 and overkill.outputs.get("bi.resource.wood",0) <= 4,"overkill actual damage clamp")
	_check(HarvestService.strike(overkill.state,axe,1,"overkill").error != OK,"duplicate strike rejected")
	var good := HarvestService.strike(HarvestService.create("tree"),SurfaceCatalog.data().tools["bi.tool.axe"],0,"good")
	var wrong := HarvestService.strike(HarvestService.create("tree"),SurfaceCatalog.data().tools["bi.tool.stone_pick"],0,"wrong")
	_check(good.outputs.get("bi.resource.wood",0) > wrong.outputs.get("bi.resource.wood",0),"tool affinity")
	var rock := HarvestService.create("rock")
	for index: int in range(10):
		if rock.health <= 0:
			break
		rock = HarvestService.strike(rock,SurfaceCatalog.data().tools["bi.tool.stone_pick"],int(rock.revision),str(index)).state
	_check(rock.health == 0 and rock.reserves["bi.resource.stone"] >= 0,"finite rock reserves / destroyed")
	var ledger := SurfaceLedger.new()
	ledger.props[one[0].id] = overkill.state
	ledger.suppress(Vector3(1,12,1),"foundation")
	_check(ledger.suppressed(Vector3(1,12,1)),"foundation suppresses")
	ledger.release(Vector3(1,12,1),"foundation")
	_check(ledger.suppressed(Vector3(1,12,1)),"release starts deadline")
	ledger.clock += 6*SurfaceLedger.DAY
	_check(not ledger.suppressed(Vector3(1,12,1)),"deterministic grass regrowth 3-6 days")
	var reloaded := SurfaceLedger.new()
	_check(reloaded.restore(JSON.parse_string(JSON.stringify(ledger.snapshot()))) == OK and reloaded.props[one[0].id].health == 0,"destroyed prop survives serialization/stream recreation")
	var inventory := InventoryState.new()
	for index: int in range(20):
		inventory.add_item("bi.tool.axe",1)
	var overflow := InventoryTransactions.output(inventory,{"bi.resource.wood":4})
	_check(overflow.overflow.get("bi.resource.wood") == 4,"full inventory preserves output for bag")
	print("SURFACE_C01 ","PASS" if failures == 0 else "FAIL"," failures=",failures)
	get_tree().quit(1 if failures else 0)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error(label)
