class_name JianghuOptionsPage
extends VBoxContainer

## The player's choices: the hero on the desktop or in a window, the shared
## settings of every Tiamat game (sound, language and the rest), quitting,
## and the hero's record.

signal settings_requested

var desk_window: JianghuDeskWindow

var _pet_mode: CheckButton
var _record: Label

func _ready() -> void:
	add_theme_constant_override("separation", 8)
	_pet_mode = CheckButton.new()
	_pet_mode.text = tr("Live on the desktop")
	_pet_mode.disabled = not JianghuDeskWindow.is_supported()
	_pet_mode.toggled.connect(_on_pet_mode_toggled)
	add_child(_pet_mode)
	var hint := JianghuStyle.label(tr("On the desktop the hero stands on the taskbar and clicks pass through. Drag the hero to move them.") if JianghuDeskWindow.is_supported() else tr("This device shows the hero in a window."), 11, JianghuStyle.INK_SOFT)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(hint)
	var settings := Button.new()
	settings.text = tr("Sound, language and more")
	settings.pressed.connect(settings_requested.emit)
	add_child(settings)
	if OS.has_feature("pc") and not OS.has_feature("web"):
		var quit := Button.new()
		quit.text = tr("Rest for today (quit)")
		quit.pressed.connect(_on_quit)
		add_child(quit)
	_record = JianghuStyle.label("", 11, JianghuStyle.INK_SOFT)
	_record.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_record)
	Cultivation.changed.connect(refresh)
	refresh()

func refresh() -> void:
	if not is_visible_in_tree():
		return
	if desk_window != null:
		_pet_mode.set_pressed_no_signal(desk_window.pet_mode)
	_record.text = tr("Fights won %s, lost %s. Regions beaten %d of %d.") % [
		JianghuNumbers.format(Cultivation.wins), JianghuNumbers.format(Cultivation.losses),
		Cultivation.cleared, JianghuRegionData.find_all().size()]

func _on_pet_mode_toggled(on: bool) -> void:
	if desk_window != null:
		desk_window.set_pet_mode(on)

func _on_quit() -> void:
	# Closing the window is a save point (`AutoSave`); quitting goes the same way.
	get_tree().root.propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	get_tree().quit()
