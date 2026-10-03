class_name PauseMenu
extends CanvasLayer

@onready var resume_button: Button = $Dim/Panel/Layout/Resume
@onready var save_button: Button = $Dim/Panel/Layout/Save
@onready var load_button: Button = $Dim/Panel/Layout/Load
@onready var settings_button: Button = $Dim/Panel/Layout/Settings
@onready var title_button: Button = $Dim/Panel/Layout/ReturnTitle
@onready var status_label: Label = $Dim/Panel/Layout/Status
@onready var settings_menu: SettingsMenu = $SettingsMenu
@onready var confirm_title: ConfirmationDialog = $ConfirmTitle

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	resume_button.pressed.connect(close)
	save_button.pressed.connect(_save_game)
	load_button.pressed.connect(_load_game)
	settings_button.pressed.connect(_open_settings)
	title_button.pressed.connect(_confirm_return_to_title)
	settings_menu.closed.connect(_on_settings_closed)
	confirm_title.confirmed.connect(_return_to_title)
	SaveManager.save_completed.connect(_on_save_completed)
	SaveManager.load_completed.connect(_on_load_completed)

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel"):
		return
	if settings_menu.visible or confirm_title.visible:
		return
	if visible:
		close()
	elif not get_tree().paused:
		open()
	else:
		return
	get_viewport().set_input_as_handled()

func open() -> void:
	if visible:
		return
	visible = true
	get_tree().paused = true
	status_label.text = ""
	load_button.disabled = not SaveManager.has_save()
	resume_button.grab_focus()

func close() -> void:
	if not visible:
		return
	visible = false
	get_tree().paused = false

func _save_game() -> void:
	SaveManager.save_game()
	load_button.disabled = not SaveManager.has_save()

func _load_game() -> void:
	if not SaveManager.has_save():
		status_label.text = tr("No save available")
		return
	visible = false
	get_tree().paused = false
	var success: bool = await SaveManager.load_game()
	if not success and is_inside_tree():
		open()

func _open_settings() -> void:
	_set_main_buttons_disabled(true)
	settings_menu.open()

func _on_settings_closed() -> void:
	_set_main_buttons_disabled(false)
	load_button.disabled = not SaveManager.has_save()
	settings_button.grab_focus()

func _confirm_return_to_title() -> void:
	confirm_title.popup_centered()

func _return_to_title() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://game/ui/title_screen.tscn")

func _on_save_completed(success: bool, message: String) -> void:
	if visible:
		status_label.text = tr(message) if success else tr("Save failed: %s") % tr(message)

func _on_load_completed(success: bool, message: String) -> void:
	if visible:
		status_label.text = tr(message) if success else tr("Load failed: %s") % tr(message)

func _set_main_buttons_disabled(value: bool) -> void:
	resume_button.disabled = value
	save_button.disabled = value
	load_button.disabled = value
	settings_button.disabled = value
	title_button.disabled = value
