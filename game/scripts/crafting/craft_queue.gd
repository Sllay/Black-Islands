class_name CraftQueue
extends RefCounted
signal changed
const CAPACITY := 5
var jobs: Array[CraftJob] = []
var revision := 0
var elapsed := 0.0 # Runtime only; load/reorder intentionally restarts full unit.
func enqueue(recipe_id: String, quantity: int, context: Dictionary = {}) -> Error:
	if InventoryTransactions.busy:
		return ERR_BUSY
	if jobs.size() >= CAPACITY or quantity < 1 or quantity > 9999:
		return ERR_INVALID_PARAMETER
	var job := CraftJob.new()
	job.recipe_id = recipe_id
	job.original_requested = quantity
	job.requested_remaining = quantity
	job.context = context.duplicate(true)
	jobs.append(job)
	touch()
	return OK
func cancel(id: String) -> Error:
	if InventoryTransactions.busy:
		return ERR_BUSY
	for index: int in jobs.size():
		if jobs[index].id == id:
			jobs.remove_at(index)
			if index == 0:
				elapsed = 0
			touch()
			return OK
	return ERR_DOES_NOT_EXIST
func reorder(id: String, target: int) -> Error:
	if InventoryTransactions.busy:
		return ERR_BUSY
	if target < 0 or target >= jobs.size():
		return ERR_INVALID_PARAMETER
	for index: int in jobs.size():
		if jobs[index].id == id:
			if index == target:
				return OK
			var job := jobs[index]
			jobs.remove_at(index)
			jobs.insert(target,job)
			elapsed = 0
			touch()
			return OK
	return ERR_DOES_NOT_EXIST
func touch() -> void:
	revision += 1
	changed.emit()
func snapshot() -> Dictionary:
	var rows: Array = []
	for job: CraftJob in jobs:
		rows.append(job.snapshot())
	return {"schema_version":1,"jobs":rows}
func restore(data: Dictionary) -> Error:
	if data.get("schema_version",1) != 1:
		return ERR_UNAVAILABLE
	if not data.get("jobs",[]) is Array or data.get("jobs",[]).size() > CAPACITY:
		return ERR_INVALID_DATA
	var loaded: Array[CraftJob] = []
	var ids := {}
	for row: Variant in data.get("jobs",[]):
		if not row is Dictionary or not row.get("id") is String or not row.get("recipe_id") is String or not row.get("context",{}) is Dictionary:
			return ERR_INVALID_DATA
		var quantity: Variant = row.get("requested_remaining")
		var requested: Variant = row.get("original_requested",quantity)
		if not (quantity is int or quantity is float) or not (requested is int or requested is float) or quantity < 1 or quantity != int(quantity) or requested < quantity or requested > 9999 or requested != int(requested) or ids.has(row.id):
			return ERR_INVALID_DATA
		var job := CraftJob.new()
		job.id = row.id
		job.recipe_id = row.recipe_id
		job.requested_remaining = int(quantity)
		job.original_requested = int(requested)
		job.context = row.get("context",{}).duplicate(true)
		ids[job.id] = true
		loaded.append(job)
	jobs = loaded
	elapsed = 0
	touch()
	return OK
