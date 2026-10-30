class_name InventoryGestureController
extends Node
## One pointer/timer authority; no timers or finger bookkeeping in slot widgets.
signal tap(slot: InventorySlotView)
signal double_tap(slot: InventorySlotView)
signal dropped(payload: Dictionary, target: InventorySlotView)
signal drag_visual(point: Vector2, row: Dictionary)
signal drag_finished
var tuning: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/inventory/interaction.json"))
var slots: Array[InventorySlotView] = []
var enabled := true
var held: InventorySlotView
var payload: Dictionary = {}
var dragging := false
var moved := false
var start := Vector2.ZERO
var point := Vector2.ZERO
var pressed_at := 0
var pointer := -99
var pending: InventorySlotView
var pending_uid := ""
var _hold: Timer
var _tap: Timer
func _ready() -> void:
	_hold = Timer.new()
	_hold.one_shot = true
	_hold.wait_time = float(tuning.long_press_seconds)
	_hold.timeout.connect(_long_press)
	add_child(_hold)
	_tap = Timer.new()
	_tap.one_shot = true
	_tap.wait_time = float(tuning.double_tap_seconds)
	_tap.timeout.connect(func() -> void:
		if is_instance_valid(pending) and pending.row.get("stack_uid","") == pending_uid:
			tap.emit(pending)
		pending = null)
	add_child(_tap)
func slot_event(slot: InventorySlotView, event: InputEvent) -> void:
	if not enabled or event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		_down(slot,slot.get_global_transform_with_canvas()*event.position,-1)
	elif event is InputEventScreenTouch and event.pressed:
		_down(slot,slot.get_global_transform_with_canvas()*event.position,event.index)
func _down(slot: InventorySlotView, at: Vector2, finger: int) -> void:
	if held != null:
		return
	held = slot
	pointer = finger
	start = at
	point = at
	pressed_at = Time.get_ticks_msec()
	moved = false
	payload = {"store":slot.store,"uid":slot.row.get("stack_uid",""),"revision":slot.store.revision,"slot":slot}
	_hold.start()
func _input(event: InputEvent) -> void:
	if not enabled or event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenTouch and event.pressed and held == null:
		for slot: InventorySlotView in slots:
			if is_instance_valid(slot) and slot.is_visible_in_tree() and slot.get_global_rect().has_point(event.position):
				_down(slot,event.position,event.index)
				break
	if held == null:
		return
	if event is InputEventMouseMotion and pointer == -1:
		_move(event.position)
	elif event is InputEventScreenDrag and event.index == pointer:
		_move(event.position)
	elif event is InputEventMouseButton and pointer == -1 and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_up(event.position)
	elif event is InputEventScreenTouch and event.index == pointer and not event.pressed:
		_up(event.position)
func _move(at: Vector2) -> void:
	point = at
	if not dragging and point.distance_to(start) > float(tuning.drag_threshold_logical_px):
		moved = true
		_hold.stop()
		_tap.stop()
		pending = null
	if dragging:
		drag_visual.emit(point,held.row)
		get_viewport().set_input_as_handled()
func _long_press() -> void:
	if held == null or moved or payload.uid.is_empty():
		return
	_tap.stop()
	pending = null
	dragging = true
	InventoryLayoutPolicy.begin(held.store.inventory_id)
	drag_visual.emit(point,held.row)
func _up(at: Vector2) -> void:
	_hold.stop()
	if dragging:
		var target: InventorySlotView
		for slot: InventorySlotView in slots:
			if is_instance_valid(slot) and slot.is_visible_in_tree() and slot.get_global_rect().has_point(at):
				target = slot
				break
		if target != null:
			dropped.emit(payload,target)
		InventoryLayoutPolicy.end(held.store.inventory_id)
		drag_finished.emit()
	elif not moved and Time.get_ticks_msec()-pressed_at <= float(tuning.tap_max_seconds)*1000:
		if pending == held and pending_uid == payload.uid and not _tap.is_stopped():
			_tap.stop()
			pending = null
			double_tap.emit(held)
		else:
			pending = held
			pending_uid = payload.uid
			_tap.start()
	held = null
	payload = {}
	dragging = false
func cancel() -> void:
	if dragging and held != null:
		InventoryLayoutPolicy.end(held.store.inventory_id)
	if _hold != null:
		_hold.stop()
		_tap.stop()
	held = null
	pending = null
	payload = {}
	dragging = false
	drag_finished.emit()
