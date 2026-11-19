class_name GameTitleBase
extends ColorRect

## What every title screen does, however it looks: it opens a save slot
## (continuing its game, or starting a new one there), deletes a slot's saves
## after asking, opens the settings and quits.
##
## GameTitleScreen, the core's menu, is one; a game whose old title had a look
## of its own extends this instead and shows the slots its own way. It calls
## the actions below from its buttons and overrides the three views:
## `_refresh_slot_ui` (show the slots as they are now), `_set_buttons_disabled`
## (hold the menu while a game opens or a dialog is up) and `_show_status`
## (a line that says what went wrong or what was done).
##
## The questions it asks and the settings menu are the scene's own
## `ConfirmNewGame`, `ConfirmDelete` and `SettingsMenu` when it has them, or
## are made here when it has not.

const SETTINGS_MENU := preload("res://tiamat/core/ui/settings_menu.tscn")

var settings_menu: SettingsMenu
var confirm_new_game: ConfirmationDialog
var confirm_delete: ConfirmationDialog

func _ready() -> void:
	settings_menu = get_node_or_null(^"SettingsMenu") as SettingsMenu
	if settings_menu == null:
		settings_menu = SETTINGS_MENU.instantiate() as SettingsMenu
		settings_menu.name = "SettingsMenu"
		add_child(settings_menu)
	confirm_new_game = _question(&"ConfirmNewGame", "Start New Game", "Start New Game")
	confirm_delete = _question(&"ConfirmDelete", "Delete Save", "Delete")
	settings_menu.closed.connect(_on_settings_closed)
	confirm_new_game.confirmed.connect(_start_new_game)
	confirm_delete.confirmed.connect(_confirm_delete_save)
	SaveManager.load_completed.connect(_on_load_completed)
	GameSession.new_game_failed.connect(_on_new_game_failed)

## Whether this platform can quit from a menu: a web page is left by closing
## its tab.
static func can_quit() -> bool:
	return not OS.has_feature("web")

## Opens `slot` the way the old games' slot cards did: it continues the game
## saved there, or starts a new game in it when it holds none (asking first
## when it holds a save this version cannot open).
func open_slot(slot: int) -> void:
	SaveManager.select_slot(slot)
	_show_status("")
	if SaveManager.has_save():
		_continue_game()
	else:
		_new_game()

## Asks to delete what `slot` holds.
func delete_slot(slot: int) -> void:
	SaveManager.select_slot(slot)
	_show_status("")
	_delete_save()

# The views a title screen overrides.
func _refresh_slot_ui() -> void:
	pass

func _set_buttons_disabled(_value: bool) -> void:
	pass

func _show_status(_text: String) -> void:
	pass

## A save's summary as the core's slot shows it: the date and time, marked
## when the slot continues from its autosave; where the player stands and how
## long they played; then what the game and its modules add (the money, the
## deepest depth).
func _format_slot_summary(summary: Dictionary) -> String:
	var minute := int(summary["minute_of_day"])
	var recovery := ""
	if bool(summary["recoverable"]):
		recovery = tr(" · temporary save recovery") if String(summary["recovery_source"]) == "temp" else tr(" · backup available")
	var lines := PackedStringArray([tr("%s · %02d:%02d%s") % [
		GameCalendar.current().get_date_text(int(summary["day"])),
		minute / 60,
		minute % 60,
		recovery,
	]])
	if bool(summary.get("autosave", false)):
		lines[0] = tr("Autosave · %s") % lines[0]
	var played_minutes := int(summary.get("play_seconds", 0)) / 60
	var played := tr("Played %d:%02d") % [played_minutes / 60, played_minutes % 60]
	var place := String(summary.get("location_name", ""))
	lines.append("%s · %s" % [tr(place), played] if not place.is_empty() else played)
	var details: PackedStringArray = summary.get("details", PackedStringArray())
	if not details.is_empty():
		lines.append(" · ".join(details))
	return "\n".join(lines)

# A new game in the selected slot, asking first when that replaces something.
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
	_show_status(tr("Could not open the starting location"))
	_set_buttons_disabled(false)
	_refresh_slot_ui()

func _continue_game() -> void:
	_set_buttons_disabled(true)
	_show_status(tr("Loading Slot %d...") % SaveManager.active_slot)
	# Not awaited: a load that succeeds frees the title screen.
	GameSession.continue_game()

# A load that succeeds frees the title screen with its scene.
func _on_load_completed(success: bool, message: String) -> void:
	if success:
		return
	_show_status(message)
	_set_buttons_disabled(false)
	_refresh_slot_ui()

func _delete_save() -> void:
	if not SaveManager.has_files():
		return
	confirm_delete.dialog_text = tr("Delete Save Slot %d? This removes its save, its autosave and their backups.") % SaveManager.active_slot
	confirm_delete.popup_centered()

func _confirm_delete_save() -> void:
	var slot := SaveManager.active_slot
	var success := SaveManager.delete_save()
	_show_status(tr("Deleted Slot %d") % slot if success else tr("Could not delete Slot %d") % slot)
	_refresh_slot_ui()

func _open_settings() -> void:
	_set_buttons_disabled(true)
	settings_menu.open()

func _on_settings_closed() -> void:
	_set_buttons_disabled(false)
	_refresh_slot_ui()

func _quit() -> void:
	get_tree().quit()

# The scene's own question, or a new one with the core's words.
func _question(node_name: StringName, title_text: String, ok_text: String) -> ConfirmationDialog:
	var dialog := get_node_or_null(NodePath(node_name)) as ConfirmationDialog
	if dialog != null:
		return dialog
	dialog = ConfirmationDialog.new()
	dialog.name = node_name
	dialog.title = title_text
	dialog.size = Vector2i(300, 100)
	dialog.dialog_autowrap = true
	dialog.ok_button_text = ok_text
	dialog.cancel_button_text = "Cancel"
	add_child(dialog)
	return dialog
