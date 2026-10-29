extends Node
var failures := 0
func _ready() -> void:
	_farming()
	_support()
	_transactions()
	print("SURFACE_C02 ","PASS" if failures == 0 else "FAIL"," failures=",failures)
	get_tree().quit(1 if failures else 0)

func _check(condition: bool, label: String) -> void:
	if not condition:
		failures += 1
		push_error("SURFACE_C02 "+label)

func _farming() -> void:
	var ledger := SurfaceLedger.new()
	var farms := FarmSystem.new(ledger)
	var inventory := InventoryState.new()
	InventoryTransactions.output(inventory,{"bi.seed.turnip":4})
	var point := Vector3(.5,12.02,.5)
	var key := SurfaceLedger.cell_key(point)
	_check(farms.till(point,false,1) != OK and farms.till(point,true,3) != OK,"unsupported/non-tillable hoe rejected")
	_check(farms.till(point,true,1) == OK and ledger.suppressed(point),"hoe dedicated plot + suppression")
	_check(farms.plant(key,inventory) == OK and inventory.slot_at(0).quantity == 3,"seed paid once")
	_check(farms.plant(key,inventory) != OK,"double seed rejected")
	farms.water(key)
	ledger.clock += SurfaceLedger.DAY
	farms.evaluate()
	_check(is_equal_approx(float(farms.plots[key].growth_progress),.5),"one day of moisture / growth")
	ledger.clock += SurfaceLedger.DAY
	farms.evaluate()
	_check(is_equal_approx(float(farms.plots[key].growth_progress),.5),"dry plot does not grow")
	farms.rain(AABB(Vector3(-1,0,-1),Vector3(3,30,3)),true)
	_check(farms.plots[key].moisture_deadline == ledger.clock+SurfaceLedger.DAY*3,"heavy rain seam up to three days")
	ledger.clock += SurfaceLedger.DAY
	farms.evaluate()
	_check(farms.plots[key].growth_progress == 1 and farms.harvest(key).get("bi.food.turnip") == 3,"turnip growth / harvest")
	_check(farms.harvest(key).is_empty(),"no repeated crop output")
	farms.plant(key,inventory)
	_check(farms.remove(key,true).get("bi.seed.turnip") == 1 and not farms.plots.has(key),"support removal breaks plot and definition returns seed")
	farms.till(point,true,1)
	ledger.active_seconds += 1801
	_check(key in farms.evaluate(),"empty dry plot thirty active minutes decay")

func _support() -> void:
	var graph := SupportGraph.new()
	graph.ground = func(cell: Vector3i) -> bool: return cell.y == 0 and cell.x in [0,4]
	_check(graph.place("rootA","foundation",Vector3i.ZERO) == OK,"foundation real root")
	_check(graph.place("c1","ceiling",Vector3i(1,0,0)) == OK and graph.place("c2","ceiling",Vector3i(2,0,0)) == OK,"two-cell reach")
	_check(graph.place("c3","ceiling",Vector3i(3,0,0)) != OK,"third unsupported ceiling rejected")
	_check(graph.place("wall","wall",Vector3i(2,0,0),0) == OK,"wall on cantilever")
	_check(graph.place("upper","ceiling",Vector3i(2,2,0)) == OK,"wall transmits original root vertically")
	_check(graph.place("stair_exploit","ceiling",Vector3i(3,2,0)) != OK,"wall never resets root")
	_check(graph.place("floating_pillar","pillar",Vector3i(2,2,0)) == OK,"floating pillar inherits")
	_check(graph.place("pillar_exploit","ceiling",Vector3i(3,2,0)) != OK,"floating pillar never resets root")
	_check(graph.place("double_wall","wall",Vector3i(3,0,0),2) == ERR_ALREADY_IN_USE,"opposite side same edge rejects double wall")
	_check(graph.place("rootB","foundation",Vector3i(4,0,0),0,"stone") == OK,"second real root different material")
	_check(graph.place("bridge3","ceiling",Vector3i(3,0,0)) == OK,"bridge from rootB")
	graph.remove("rootA")
	_check(graph.pieces.has("c2") and graph.pieces.has("bridge3") and not graph.pieces.has("c1"),"alternate root preserves supported subset only")
	_check(graph.place("too_high","pillar",Vector3i(4,100,0)) != OK,"absolute height limit")
	var snapshot := graph.pieces.duplicate(true)
	var rebuilt := SupportGraph.new()
	rebuilt.ground = graph.ground
	_check(rebuilt.restore(JSON.parse_string(JSON.stringify(snapshot))) == OK and rebuilt.candidates.get("bridge3",{}).has("rootB"),"rebuild support from persisted geometry")
	var large := SupportGraph.new()
	large.ground = func(cell: Vector3i) -> bool: return cell.y == 0
	for cluster: int in range(60):
		var x := cluster*10
		large.place("f%d"%cluster,"foundation",Vector3i(x,0,0))
		large.place("p%d"%cluster,"pillar",Vector3i(x+2,0,0))
		large.place("b%d"%cluster,"ceiling",Vector3i(x+1,0,0))
		large.place("a%d"%cluster,"ceiling",Vector3i(x+2,0,0))
		large.place("u%d"%cluster,"ceiling",Vector3i(x+2,2,0))
	large.remove("f0")
	_check(large.last_benchmark.examined <= 5 and large.pieces.has("u59"),"local recompute excludes remote structures")
	print("SUPPORT_BENCHMARK pieces=",large.pieces.size()," ",large.last_benchmark)

func _count(store: InventoryState) -> int:
	var count := 0
	for index: int in InventoryState.CAPACITY:
		count += int(store.slot_at(index).get("quantity",0))
	return count

func _transactions() -> void:
	var a := InventoryState.new()
	a.inventory_id = "qa.player"
	var b := InventoryState.new()
	b.inventory_id = "qa.chest"
	InventoryTransactions.output(a,{"bi.resource.stone":500})
	var row := a.slot_at(0)
	var revision := a.revision
	_check(InventoryTransactions.transfer(a,b,row.stack_uid,7,a.revision,b.revision) == OK,"partial transfer")
	_check(InventoryTransactions.transfer(a,b,row.stack_uid,7,revision,0) == ERR_ALREADY_IN_USE,"stale transfer rejected")
	row = a.slot_at(0)
	_check(InventoryTransactions.transfer(a,b,row.stack_uid,int(row.quantity),a.revision,b.revision) == OK,"full stack transfer")
	var successes := 0
	var rejections := 0
	for index: int in range(3000):
		var source := a if index%2 == 0 else b
		var target := b if source == a else a
		var stack: Dictionary = {}
		for slot: int in InventoryState.CAPACITY:
			stack = source.slot_at(slot)
			if not stack.is_empty():
				break
		if stack.is_empty():
			continue
		var source_revision := source.revision
		var target_revision := target.revision
		if index%3 == 0:
			InventoryTransactions.output(source,{}) # Legitimate revision-only interleaving.
		var error := InventoryTransactions.transfer(source,target,stack.stack_uid,1,source_revision,target_revision)
		successes += int(error == OK)
		rejections += int(error == ERR_ALREADY_IN_USE)
		_check(_count(a)+_count(b) == 500,"conservation after interleaving")
	print("TRANSACTION_STRESS attempted=3000 success=",successes," stale=",rejections," before=500 after=",_count(a)+_count(b))
