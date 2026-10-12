class_name PauseMenu
extends MenuLayer

## The pause menu every game's locations share: the core's `pause` control
## (Esc, Start) opens it over the paused world, to resume, save, load, change
## the settings, return to the title screen (the game's main scene) or quit;
## `pause` or `ui_cancel` closes it. It also opens when the window loses focus
## (`GameSettings.pause_on_focus_loss`) or the gamepad in use disconnects
## (`InputPrompts.gamepad_disconnected`), over the world or over a minigame,
## which stands still under it, and `quick_load` asks here before a load
## throws away the progress since the last save. A load here takes the
## player's own save, not a newer autosave, so going back to what they saved
## stays one step; with no save of their own, it takes the autosave.

## The menu's id: its group and the reason of its lock, held while the game
## is paused for the player (`GameSession` counts no time played then).
const MENU_ID := &"pause_menu"
## The control that opens and closes the menu (`core/input/controls/pause.tres`).
const PAUSE_ACTION := &"pause"

@onready var resume_button: Button = $Dim/Panel/Layout/Resume
@onready var save_button: Button = $Dim/Panel/Layout/Save
@onready var load_button: Button = $Dim/Panel/Layout/Load
@onready var settings_button: Button = $Dim/Panel/Layout/Settings
@onready var title_button: Button = $Dim/Panel/Layout/ReturnTitle
@onready var quit_button: Button = $Dim/Panel/Layout/Quit
@onready var status_label: Label = $Dim/Panel/Layout/Status
@onready var settings_menu: SettingsMenu = $SettingsMenu
@onready var confirm_load: ConfirmationDialog = $ConfirmLoad
@onready var confirm_title: ConfirmationDialog = $ConfirmTitle
@onready var confirm_quit: ConfirmationDialog = $ConfirmQuit

# Whether the load this menu started is under way.
var _loading := false

func _init() -> void:
	super(MENU_ID)

func _ready() -> void:
	# A web page is left by closing its tab.
	quit_button.visible = not OS.has_feature("web")
	resume_button.pressed.connect(close)
	save_button.pressed.connect(_save_game)
	load_button.pressed.connect(request_load)
	settings_button.pressed.connect(_open_settings)
	title_button.pressed.connect(confirm_title.popup_centered)
	quit_button.pressed.connect(confirm_quit.popup_centered)
	settings_menu.closed.connect(_on_settings_closed)
	confirm_load.confirmed.connect(_load_game)
	confirm_title.confirmed.connect(_return_to_title)
	confirm_quit.confirmed.connect(_quit)
	for dialog: ConfirmationDialog in [confirm_load, confirm_title, confirm_quit]:
		dialog.canceled.connect(_on_dialog_canceled.bind(dialog))
	SaveManager.save_completed.connect(_on_save_completed)
	SaveManager.load_completed.connect(_on_load_completed)
	InputPrompts.gamepad_disconnected.connect(_on_gamepad_disconnected)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and GameSettings.pause_on_focus_loss and _runs_unwatched():
		open()

func _on_gamepad_disconnected() -> void:
	if _runs_unwatched():
		open()

# Whether play goes on while the player looks away: the world runs, or a
# minigame does over it. A menu or a dialogue on top waits for the player.
func _runs_unwatched() -> bool:
	return not get_tree().paused or InputLock.get_top_reason() == MiniGameHostService.LOCK_REASON

func _unhandled_input(event: InputEvent) -> void:
	var pause := InputMap.has_action(PAUSE_ACTION) and event.is_action_pressed(PAUSE_ACTION)
	var cancel := event.is_action_pressed("ui_cancel")
	var quick_load := event.is_action_pressed("quick_load")
	if not pause and not cancel and not quick_load:
		return
	if settings_menu.visible or _is_dialog_open():
		return
	if not visible:
		# Cancel only leaves the menu; something else may hold the input (a
		# menu, a minigame, a travel).
		if (cancel and not pause and not quick_load) or InputLock.is_locked():
			return
		open()
	elif not InputLock.is_top(self):
		return
	elif pause or cancel:
		close()
	if quick_load and visible:
		request_load()
	get_viewport().set_input_as_handled()

## Opens the menu, unless a travel is changing the scene: what the menu
## offers (a load, the title) would race it.
func open() -> void:
	if visible or WorldTravel.is_traveling():
		return
	show_menu()
	status_label.text = ""
	load_button.disabled = not SaveManager.has_save()
	resume_button.grab_focus()

func close() -> void:
	if not visible:
		return
	settings_menu.close()
	for dialog: ConfirmationDialog in [confirm_load, confirm_title, confirm_quit]:
		dialog.hide()
	super()

## Asks before loading the player's save (or the autosave, with none of their
## own) over the progress since.
func request_load() -> void:
	if not SaveManager.has_save():
		status_label.text = tr("No save available")
		return
	var autosave := get_load_kind() == GameSaveManager.SaveKind.AUTO
	confirm_load.dialog_text = tr("Unsaved progress will be lost. Load the autosave?") if autosave else tr("Unsaved progress will be lost. Load your last save?")
	confirm_load.popup_centered()

func _is_dialog_open() -> bool:
	return confirm_load.visible or confirm_title.visible or confirm_quit.visible

func _save_game() -> void:
	SaveManager.save_game()
	load_button.disabled = not SaveManager.has_save()

func _load_game() -> void:
	close()
	# Not awaited: a load that succeeds frees this menu with its location.
	_loading = true
	SaveManager.load_game(get_load_kind())

## Which of the slot's saves a load here takes: the player's own, else the
## autosave.
static func get_load_kind() -> GameSaveManager.SaveKind:
	return GameSaveManager.SaveKind.MANUAL if SaveManager.has_save(-1, GameSaveManager.SaveKind.MANUAL) else GameSaveManager.SaveKind.AUTO

func _open_settings() -> void:
	_set_main_buttons_disabled(true)
	settings_menu.open()

func _on_settings_closed() -> void:
	_set_main_buttons_disabled(false)
	load_button.disabled = not SaveManager.has_save()
	if visible:
		settings_button.grab_focus()

func _on_dialog_canceled(dialog: ConfirmationDialog) -> void:
	if not visible:
		return
	if dialog == confirm_load:
		load_button.grab_focus()
	elif dialog == confirm_title:
		title_button.grab_focus()
	else:
		quit_button.grab_focus()

func _return_to_title() -> void:
	if not GameSession.return_to_title():
		status_label.text = tr("Cannot return to the title while the scene changes")

func _quit() -> void:
	get_tree().quit()

func _on_save_completed(_success: bool, message: String) -> void:
	if visible:
		status_label.text = message

func _on_load_completed(success: bool, message: String) -> void:
	if _loading:
		_loading = false
		if not success:
			open()
	if visible:
		status_label.text = message

func _set_main_buttons_disabled(value: bool) -> void:
	resume_button.disabled = value
	save_button.disabled = value
	load_button.disabled = value
	settings_button.disabled = value
	title_button.disabled = value
	quit_button.disabled = value
