class_name InventoryPlan
extends RefCounted
var stores: Array[InventoryState] = []
var copies: Array[InventoryState] = []
var revisions: Array[int] = []
var publications: Array[InventoryPublication] = []
var error: Error = OK
var amount := 0
func include(store: InventoryState) -> InventoryState:
	var index := stores.find(store)
	if index >= 0:
		return copies[index]
	stores.append(store)
	revisions.append(store.revision)
	var copy := InventoryTransactions.clone(store)
	copies.append(copy)
	return copy
func commit() -> Error:
	return error if error != OK else InventoryTransactions.commit(stores,copies,revisions,publications)
