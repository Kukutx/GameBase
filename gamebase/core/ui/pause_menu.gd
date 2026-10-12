class_name PauseMenu
extends CanvasLayer

## The pause menu every game's locations share: `ui_cancel` opens it over the
## paused world, to resume, save, load, change the settings, return to the
## title screen (the game's main scene) or quit. It also opens when the window
## loses focus (`GameSettings.pause_on_focus_loss`), and `quick_load` asks
## here before a load throws away the progress since the last save.

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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
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

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_node_ready() and GameSettings.pause_on_focus_loss and not get_tree().paused:
		open()

func _unhandled_input(event: InputEvent) -> void:
	var cancel := event.is_action_pressed("ui_cancel")
	var quick_load := event.is_action_pressed("quick_load")
	if not cancel and not quick_load:
		return
	if settings_menu.visible or _is_dialog_open():
		return
	if not visible:
		# Something else that paused the world has the input.
		if get_tree().paused:
			return
		open()
	elif cancel:
		close()
	if quick_load and visible:
		request_load()
	get_viewport().set_input_as_handled()

## Opens the menu, unless a travel is changing the scene: what the menu
## offers (a load, the title) would race it.
func open() -> void:
	if visible or WorldTravel.is_traveling():
		return
	visible = true
	InputLock.lock(&"pause_menu", true, self)
	status_label.text = ""
	load_button.disabled = not SaveManager.has_save()
	resume_button.grab_focus()

func close() -> void:
	if not visible:
		return
	visible = false
	settings_menu.close()
	for dialog: ConfirmationDialog in [confirm_load, confirm_title, confirm_quit]:
		dialog.hide()
	InputLock.unlock(&"pause_menu")

## Asks before loading the last save over the progress since.
func request_load() -> void:
	if not SaveManager.has_save():
		status_label.text = tr("No save available")
		return
	confirm_load.popup_centered()

func _is_dialog_open() -> bool:
	return confirm_load.visible or confirm_title.visible or confirm_quit.visible

func _save_game() -> void:
	SaveManager.save_game()
	load_button.disabled = not SaveManager.has_save()

func _load_game() -> void:
	visible = false
	InputLock.unlock(&"pause_menu")
	# Not awaited: a load that succeeds frees this menu with its location.
	_loading = true
	SaveManager.load_game()

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

func _on_save_completed(success: bool, message: String) -> void:
	if visible:
		status_label.text = message if success else tr("Save failed: %s") % message

func _on_load_completed(success: bool, message: String) -> void:
	if _loading:
		_loading = false
		if not success:
			open()
	if visible:
		status_label.text = message if success else tr("Load failed: %s") % message

func _set_main_buttons_disabled(value: bool) -> void:
	resume_button.disabled = value
	save_button.disabled = value
	load_button.disabled = value
	settings_button.disabled = value
	title_button.disabled = value
	quit_button.disabled = value
