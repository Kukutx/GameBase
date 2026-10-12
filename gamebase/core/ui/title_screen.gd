class_name GameTitleScreen
extends ColorRect

## The title screen every game opens on (its main scene): the game's name,
## description and version from the project settings, its save slots, a new
## game, the settings and quitting. It takes the game's `GameDefinition.ui_theme`.

@onready var title_label: Label = $Center/Menu/Title
@onready var subtitle_label: Label = $Center/Menu/Subtitle
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
	theme = GameDefinition.current().ui_theme
	title_label.text = String(ProjectSettings.get_setting("application/config/name", ""))
	subtitle_label.text = String(ProjectSettings.get_setting("application/config/description", ""))
	subtitle_label.visible = not subtitle_label.text.is_empty()
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
	GameSession.continue_started.connect(_on_continue_started)
	GameSession.new_game_failed.connect(_on_new_game_failed)
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
	var exists := bool(summary["exists"])
	var unreadable := bool(summary["unreadable"])
	continue_button.disabled = not exists
	delete_button.disabled = not exists and not unreadable
	if exists:
		slot_info.text = _format_slot_summary(summary)
	else:
		slot_info.text = tr("Holds a save this version cannot open") if unreadable else tr("Empty slot")

func _format_slot_summary(summary: Dictionary) -> String:
	var minute := int(summary["minute_of_day"])
	var recovery := ""
	if bool(summary["recoverable"]):
		recovery = tr(" · temporary save recovery") if String(summary["recovery_source"]) == "temp" else tr(" · backup available")
	return tr("%s · %02d:%02d · %dg%s") % [
		GameCalendar.current().get_date_text(int(summary["day"])),
		minute / 60,
		minute % 60,
		int(summary["money"]),
		recovery,
	]

func _new_game() -> void:
	if SaveManager.has_save():
		confirm_new_game.dialog_text = tr("Save Slot %d already contains a game. Starting a new game will replace this slot. Continue?") % SaveManager.active_slot
		confirm_new_game.popup_centered()
		return
	if SaveManager.has_files():
		confirm_new_game.dialog_text = tr("Save Slot %d holds a save this version cannot open. Starting a new game will replace it. Continue?") % SaveManager.active_slot
		confirm_new_game.popup_centered()
		return
	_start_new_game()

func _start_new_game() -> void:
	_set_buttons_disabled(true)
	# GameSession owns replacement of the selected slot so it can preflight the
	# starting Location before any destructive save operation occurs.
	if not GameSession.start_new_game():
		_on_new_game_failed()

# The start location did not open, at once or once its scene failed to load.
func _on_new_game_failed() -> void:
	status_label.text = tr("Could not open the starting location")
	_set_buttons_disabled(false)
	_refresh_slot_ui()

func _continue_game() -> void:
	_set_buttons_disabled(true)
	status_label.text = tr("Loading Slot %d...") % SaveManager.active_slot
	# Not awaited: a load that succeeds frees the title screen.
	GameSession.continue_game()

func _on_continue_started(success: bool) -> void:
	if success:
		return
	status_label.text = tr("No valid save found")
	_set_buttons_disabled(false)
	_refresh_slot_ui()

func _delete_save() -> void:
	if not SaveManager.has_files():
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
