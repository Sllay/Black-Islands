class_name CraftService
extends RefCounted
signal changed
var catalog := RecipeCatalog.new()
var queue := CraftQueue.new()
var resolve_scope: Callable
var drops: WorldDropService
var _cache: Dictionary = {}
var cache_misses := 0
var completions := 0
var _dirty := true
func scope(context: Dictionary) -> ResourceScope:
	return resolve_scope.call(context) if resolve_scope.is_valid() else null
func availability(recipe: RecipeDefinition, context: Dictionary = {}) -> Dictionary:
	var resources := scope(context)
	if resources == null or not resources.permits(recipe):
		return {"quantity":0,"counts":{}}
	var key := recipe.id+JSON.stringify(context)
	var stamp := resources.signature()
	if _cache.has(key) and _cache[key].stamp == stamp:
		return _cache[key].value
	cache_misses += 1
	var counts := resources.counts()
	var quantity := 9999
	for id: String in recipe.costs():
		quantity = mini(quantity,int(int(counts.get(id,0))/float(recipe.costs()[id])))
	var value := {"quantity":quantity,"counts":counts}
	_cache[key] = {"stamp":stamp,"value":value}
	return value
func enqueue(id: String, quantity: int, context: Dictionary = {}) -> Error:
	var recipe := catalog.resolve(id)
	if recipe == null or availability(recipe,context).quantity < 1:
		return ERR_UNAVAILABLE
	var error := queue.enqueue(id,quantity,context)
	if error == OK:
		invalidate()
	return error
func invalidate() -> void:
	_dirty = true
	_cache.clear()
	changed.emit()
func refresh() -> void:
	if not _dirty or InventoryTransactions.busy:
		return
	_dirty = false
	var altered := false
	for index: int in range(queue.jobs.size()-1,-1,-1):
		var job := queue.jobs[index]
		var recipe := catalog.resolve(job.recipe_id)
		var possible := 0 if recipe == null else int(availability(recipe,job.context).quantity)
		var amount := mini(job.requested_remaining,possible)
		if amount != job.requested_remaining:
			job.requested_remaining = amount
			altered = true
		if amount == 0:
			queue.jobs.remove_at(index)
			if index == 0:
				queue.elapsed = 0
	if altered:
		queue.touch()
func tick(delta: float) -> void:
	refresh()
	if queue.jobs.is_empty() or InventoryTransactions.busy:
		return
	var recipe := catalog.resolve(queue.jobs[0].recipe_id)
	queue.elapsed += maxf(0,delta)
	if recipe != null and queue.elapsed >= recipe.duration:
		request_completion(queue.jobs[0])
func completion_plan(job: CraftJob) -> InventoryPlan:
	var recipe := catalog.resolve(job.recipe_id)
	if recipe == null or queue.jobs.is_empty() or queue.jobs[0] != job:
		var invalid := InventoryPlan.new()
		invalid.error = ERR_UNAVAILABLE
		return invalid
	var plan := CraftTransaction.build(recipe,scope(job.context),drops)
	var expected := queue.revision
	var remaining := job.requested_remaining
	var publication := InventoryPublication.new()
	publication.validate = func() -> bool: return queue.revision == expected and not queue.jobs.is_empty() and queue.jobs[0] == job and job.requested_remaining == remaining
	publication.apply = func() -> void:
		job.requested_remaining -= 1
		if job.requested_remaining == 0:
			queue.jobs.pop_front()
		queue.elapsed = 0
		queue.revision += 1
		completions += 1
	publication.notify = func() -> void:
		queue.changed.emit()
		invalidate()
	plan.publications.append(publication)
	return plan
func request_completion(job: CraftJob) -> Error:
	var error := completion_plan(job).commit()
	if error != OK:
		queue.elapsed = 0
		invalidate()
	return error
