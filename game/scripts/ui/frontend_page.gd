class_name FrontendPage
extends Control
## Shared responsive full-screen frame, content and persistent bottom actions.
var content: VBoxContainer
var footer: HBoxContainer
var notice: Label

func frame(title: String, subtitle: String = "") -> void:
	ShellUI.setup(self)
	var safe := ShellSafeArea.new()
	add_child(safe)
	var column := ShellUI.column(safe,12)
	column.add_child(ShellUI.label_text(title,32,ShellUI.GOLD))
	if not subtitle.is_empty():
		column.add_child(ShellUI.label_text(subtitle,18,ShellUI.MUTED))
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	content = ShellUI.column(scroll,8)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	notice = ShellUI.label_text("",18,ShellUI.GOLD)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(notice)
	footer = HBoxContainer.new()
	footer.add_theme_constant_override("separation",12)
	column.add_child(footer)

func action(parent: Node, title: String, callback: Callable, id: String = "", disabled: bool = false) -> Button:
	var button := ShellUI.button(title,id,Vector2(110,52))
	button.disabled = disabled
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func field(parent: Node, title: String, text: String, id: String) -> LineEdit:
	parent.add_child(ShellUI.label_text(title,20,ShellUI.GOLD))
	var edit := LineEdit.new()
	edit.name = id
	edit.text = text
	edit.custom_minimum_size.y = 52
	edit.focus_entered.connect(func() -> void: edit.select_all.call_deferred())
	parent.add_child(edit)
	return edit

func confirm_delete(kind: String, slot: int, refresh: Callable) -> void:
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = "Excluir esta jornada? Os dados serão arquivados localmente."
	dialog.confirmed.connect(func() -> void:
		var error := Profiles.library.trash(kind,slot)
		if error == OK:
			refresh.call()
		else:
			notice.text = "Não foi possível excluir; dados preservados.")
	add_child(dialog)
	dialog.popup_centered(Vector2i(480,180))

static func duration(seconds: float) -> String:
	var minutes := floori(seconds/60.0)
	return "%dh %02dmin" % [floori(minutes/60.0),minutes%60]
