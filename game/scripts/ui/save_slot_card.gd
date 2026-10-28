class_name SaveSlotCard
extends Button

signal chosen(slot_id: String)
var slot_id: String

func configure(summary: Dictionary, index: int) -> void:
	slot_id = summary.slot_id
	name = "Slot%02d" % (index + 1)
	custom_minimum_size = Vector2(440, 160)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	disabled = summary.state == "unavailable"
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side: String in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 20)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(margin)
	var content := ShellUI.column(margin, 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(ShellUI.label_text("%02d  /  JORNADA" % (index + 1), 16, ShellUI.MUTED))
	var title: String = summary.metadata.get("display_name", "Um novo começo")
	if disabled:
		title = "Dados indisponíveis"
	content.add_child(ShellUI.label_text(title, 27))
	var detail := "Criar jornada  →"
	if summary.state == "ready":
		detail = "Continuar  →"
		if summary.get("recovered", false):
			detail = "Continuar pelo backup  →"
	elif disabled:
		detail = "Preservado para recuperação"
	content.add_child(ShellUI.label_text(detail, 18, ShellUI.GOLD))
	pressed.connect(func() -> void: chosen.emit(slot_id))
