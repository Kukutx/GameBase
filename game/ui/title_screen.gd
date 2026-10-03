class_name GameTitleScreen
extends ColorRect

@onready var version_label: Label = $Center/Menu/Version
@onready var slot_select: OptionButton = $Center/Menu/SaveSlot
@onready var slot_info: Label = $Center/Menu/SlotInfo
@onready var continue_button: Button = $Center/Menu/Continue
@onready var new_game_button: Button = $Center/Menu/NewGame
@onready var delete_button: Button = $Center/Menu/DeleteSave
@onready var settings_button: Button = $Center/Menu/Settings
@onready var quit_button: Button = $Center/Menu/Quit
@onready var status_label: Label = $Center/Menu/Status
@onready var settings_menu: SettingsMenu = $SettingsMenu
@onready var confirm_new_game: ConfirmationDialog = $ConfirmNewGame
@onready var confirm_delete: ConfirmationDialog = $ConfirmDelete

func _ready() -> void:
	version_label.text = "v%s" % String(ProjectSettings.get_setting("application/config/version", "unknown"))
	_build_slot_selector()
	slot_select.item_selected.connect(_on_slot_selected)
	continue_button.pressed.connect(_continue_game)
	new_game_button.pressed.connect(_new_game)
	delete_button.pressed.connect(_delete_save)
	settings_button.pressed.connect(_open_settings)
	quit_button.pressed.connect(_quit)
	settings_menu.closed.connect(_on_settings_closed)
	confirm_new_game.confirmed.connect(_start_new_game)
	confirm_delete.confirmed.connect(_confirm_delete_save)
	_refresh_slot_ui()
	(new_game_button if continue_button.disabled else continue_button).grab_focus()

func _build_slot_selector() -> void:
	slot_select.clear()
	for slot in range(1, SaveManager.SLOT_COUNT + 1):
		slot_select.add_item(tr("Save Slot %d") % slot, slot)
	slot_select.select(clampi(SaveManager.active_slot - 1, 0, SaveManager.SLOT_COUNT - 1))
	SaveManager.select_slot(slot_select.selected + 1)

func _on_slot_selected(index: int) -> void:
	SaveManager.select_slot(index + 1)
	status_label.text = ""
	_refresh_slot_ui()

func _refresh_slot_ui() -> void:
	var summary := SaveManager.get_slot_summary(SaveManager.active_slot)
	var exists := bool(summary.get("exists", false))
	var loadable := bool(summary.get("loadable", exists))
	continue_button.disabled = not loadable
	delete_button.disabled = not exists
	if not exists:
		slot_info.text = tr("Empty slot")
		return
	slot_info.text = _format_slot_summary(summary, loadable)

func _format_slot_summary(summary: Dictionary, loadable: bool) -> String:
	if bool(summary.get("future_version", false)) and not loadable:
		return tr("Save v%d · requires a newer game version") % int(summary.get("version", 0))
	var minute := int(summary.get("minute_of_day", 8 * 60))
	var recovery_source := String(summary.get("recovery_source", "primary"))
	var recovery := ""
	if bool(summary.get("newer_primary_preserved", false)):
		recovery = tr(" · compatible %s · newer save preserved") % (tr("temporary recovery") if recovery_source == "temp" else tr("backup"))
	elif bool(summary.get("recoverable", false)):
		recovery = tr(" · temporary save recovery") if recovery_source == "temp" else tr(" · backup available")
	elif not loadable:
		recovery = tr(" · unavailable")
	return tr("%s %d · Day %d · %02d:%02d · %dg%s") % [
		tr(String(summary.get("season", "Spring"))),
		int(summary.get("day_of_season", 1)),
		int(summary.get("day", 1)),
		minute / 60,
		minute % 60,
		int(summary.get("money", 0)),
		recovery,
	]

func _new_game() -> void:
	if SaveManager.has_save():
		confirm_new_game.dialog_text = tr("Save Slot %d already contains a game. Starting a new game will replace this slot. Continue?") % SaveManager.active_slot
		confirm_new_game.popup_centered()
		return
	_start_new_game()

func _start_new_game() -> void:
	_set_buttons_disabled(true)
	# GameSession owns replacement of the selected slot so it can preflight the
	# starting Location before any destructive save operation occurs.
	if not GameSession.start_new_game():
		status_label.text = tr("Could not open the starting location")
		_set_buttons_disabled(false)
		_refresh_slot_ui()

func _continue_game() -> void:
	_set_buttons_disabled(true)
	status_label.text = tr("Loading Slot %d...") % SaveManager.active_slot
	var success: bool = await GameSession.continue_game()
	if not success:
		status_label.text = tr("No valid save found")
		_set_buttons_disabled(false)
		_refresh_slot_ui()

func _delete_save() -> void:
	if not SaveManager.has_save():
		return
	confirm_delete.dialog_text = tr("Delete Save Slot %d? This removes the primary save and its backup.") % SaveManager.active_slot
	confirm_delete.popup_centered()

func _confirm_delete_save() -> void:
	var slot := SaveManager.active_slot
	var success := SaveManager.delete_save()
	status_label.text = tr("Deleted Slot %d") % slot if success else tr("Could not delete Slot %d") % slot
	_refresh_slot_ui()

func _open_settings() -> void:
	_set_buttons_disabled(true)
	settings_menu.open()

func _on_settings_closed() -> void:
	_set_buttons_disabled(false)
	_build_slot_selector()
	_refresh_slot_ui()
	settings_button.grab_focus()

func _quit() -> void:
	get_tree().quit()

func _set_buttons_disabled(value: bool) -> void:
	slot_select.disabled = value
	continue_button.disabled = value
	new_game_button.disabled = value
	delete_button.disabled = value
	settings_button.disabled = value
	quit_button.disabled = value
