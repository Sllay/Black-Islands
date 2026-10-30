class_name CraftPanel
extends VBoxContainer
## Pure view/controller. Counts and feasibility come from CraftService.
var runtime: CraftRuntime
var context: Dictionary = {}
var selected := ""
var selected_job := ""
var queue_buttons: Array[Button] = []
var recipe_buttons: Dictionary = {}
var details: Label
var quantity: LineEdit
var craft: Button
var message: Label
var _timer: Timer
func _ready() -> void:
	add_theme_constant_override("separation",8)
	var tabs := HBoxContainer.new()
	add_child(tabs)
	for entry: Array in [["Player Craft",false],["Workbench Craft",true]]:
		var button := ShellUI.button(entry[0],"CraftMode",Vector2(180,44))
		button.disabled = entry[1] and runtime.station_context().is_empty()
		button.pressed.connect(func() -> void:
			context = runtime.station_context() if entry[1] else {}
			refresh())
		tabs.add_child(button)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",4)
	add_child(row)
	for index: int in CraftQueue.CAPACITY:
		var button := ShellUI.button(str(index+1),"Queue%d"%index,Vector2(84,55))
		button.add_theme_font_size_override("font_size",14)
		button.pressed.connect(func() -> void:
			selected_job = runtime.service.queue.jobs[index].id if index < runtime.service.queue.jobs.size() else ""
			refresh())
		row.add_child(button)
		queue_buttons.append(button)
	var commands := HBoxContainer.new()
	add_child(commands)
	for entry: Array in [["Remover",-1],["←",-2],["→",1]]:
		var button := ShellUI.button(entry[0],"QueueCommand",Vector2(92,42))
		button.pressed.connect(func() -> void: _queue_command(int(entry[1])))
		commands.add_child(button)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size.y = 90
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation",4)
	grid.add_theme_constant_override("v_separation",4)
	scroll.add_child(grid)
	for id: String in runtime.service.catalog.definitions:
		var recipe: RecipeDefinition = runtime.service.catalog.resolve(id)
		var button := ShellUI.button(recipe.icon+"\n"+recipe.title,"Recipe_"+id.get_slice(".",2),Vector2(84,58))
		button.add_theme_font_size_override("font_size",13)
		button.pressed.connect(func() -> void:
			selected = id
			refresh())
		grid.add_child(button)
		recipe_buttons[id] = button
	details = ShellUI.label_text("Escolha uma receita.",16)
	details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	details.custom_minimum_size = Vector2(420,76)
	add_child(details)
	var actions := HBoxContainer.new()
	add_child(actions)
	quantity = LineEdit.new()
	quantity.name = "CraftAmount"
	quantity.text = "1"
	quantity.custom_minimum_size = Vector2(85,48)
	quantity.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	actions.add_child(quantity)
	craft = ShellUI.button("Enfileirar","EnqueueCraft",Vector2(210,48))
	craft.pressed.connect(func() -> void:
		var amount := clampi(quantity.text.to_int(),1,9999)
		quantity.text = str(amount)
		var error := runtime.service.enqueue(selected,amount,context)
		message.text = "Adicionado à fila." if error == OK else "Faltam recursos, estação ou espaço na fila."
		refresh())
	actions.add_child(craft)
	message = ShellUI.label_text("Recursos são consumidos na conclusão.",14,ShellUI.MUTED)
	add_child(message)
	runtime.service.changed.connect(refresh)
	runtime.service.queue.changed.connect(refresh)
	_timer = Timer.new()
	_timer.wait_time = .25
	_timer.timeout.connect(_progress)
	add_child(_timer)
	visibility_changed.connect(_visibility)
	_visibility()
	refresh()
func refresh() -> void:
	if details == null or not is_visible_in_tree():
		return
	var service := runtime.service
	for index: int in CraftQueue.CAPACITY:
		var button := queue_buttons[index]
		button.text = str(index+1)
		if index < service.queue.jobs.size():
			var job := service.queue.jobs[index]
			var recipe := service.catalog.resolve(job.recipe_id)
			button.text = "%s %d/%d"%[recipe.icon if recipe != null else "?",job.requested_remaining,job.original_requested]
			button.modulate = ShellUI.GOLD if job.id == selected_job else Color.WHITE
	for id: String in recipe_buttons:
		var recipe := service.catalog.resolve(id)
		var value := service.availability(recipe,context)
		recipe_buttons[id].modulate = Color.WHITE if value.quantity > 0 else ShellUI.MUTED
	craft.disabled = selected.is_empty() or service.queue.jobs.size() >= CraftQueue.CAPACITY
	var recipe := service.catalog.resolve(selected)
	if recipe == null:
		return
	var available := service.availability(recipe,context)
	var text := "%s • %.1fs • disponíveis: %d\n"%[recipe.title,recipe.duration,available.quantity]
	for id: String in recipe.costs():
		text += "%s %d/%d   "%[ItemCatalog.resolve(id).title,available.counts.get(id,0),recipe.costs()[id]]
	details.text = text
func _progress() -> void:
	if runtime.service.queue.jobs.is_empty():
		return
	var recipe := runtime.service.catalog.resolve(runtime.service.queue.jobs[0].recipe_id)
	if recipe != null:
		var job := runtime.service.queue.jobs[0]
		queue_buttons[0].text = "%s %d\n%d%%"%[recipe.icon,job.requested_remaining,roundi(clampf(runtime.service.queue.elapsed/recipe.duration,0,1)*100)]
func _queue_command(direction: int) -> void:
	var queue := runtime.service.queue
	for index: int in queue.jobs.size():
		if queue.jobs[index].id == selected_job:
			if direction == -1:
				queue.cancel(selected_job)
			else:
				queue.reorder(selected_job,clampi(index+(-1 if direction == -2 else 1),0,queue.jobs.size()-1))
			runtime.service.invalidate()
			return

func _visibility() -> void:
	if _timer == null:
		return
	if is_visible_in_tree():
		_timer.start()
		refresh()
	else:
		_timer.stop()
