class_name SettingsMenu
extends CanvasLayer

signal closed

@onready var master_row: HBoxContainer = $Dim/Panel/Layout/Master
@onready var music_row: HBoxContainer = $Dim/Panel/Layout/Music
@onready var sounds_row: HBoxContainer = $Dim/Panel/Layout/Sounds
@onready var master_slider: HSlider = $Dim/Panel/Layout/Master/Slider
@onready var music_slider: HSlider = $Dim/Panel/Layout/Music/Slider
@onready var sounds_slider: HSlider = $Dim/Panel/Layout/Sounds/Slider
@onready var fullscreen_check: CheckButton = $Dim/Panel/Layout/Fullscreen
@onready var vsync_check: CheckButton = $Dim/Panel/Layout/VSync
@onready var autosave_check: CheckButton = $Dim/Panel/Layout/Autosave
@onready var language_row: HBoxContainer = $Dim/Panel/Layout/Language
@onready var language_select: OptionButton = $Dim/Panel/Layout/Language/Select
@onready var accessibility_button: Button = $Dim/Panel/Layout/AccessibilityButton
@onready var accessibility_page: VBoxContainer = $Dim/Panel/Layout/AccessibilityPage
@onready var weather_effects_check: CheckButton = $Dim/Panel/Layout/AccessibilityPage/WeatherEffects
@onready var reduced_motion_check: CheckButton = $Dim/Panel/Layout/AccessibilityPage/ReducedMotion
@onready var support_export: Button = $Dim/Panel/Layout/AccessibilityPage/ExportSupportBundle
@onready var support_open: Button = $Dim/Panel/Layout/AccessibilityPage/OpenSupportFolder
@onready var accessibility_back: Button = $Dim/Panel/Layout/AccessibilityPage/Back
@onready var controls_button: Button = $Dim/Panel/Layout/ControlsButton
@onready var controls_page: VBoxContainer = $Dim/Panel/Layout/ControlsPage
@onready var controls_list: VBoxContainer = $Dim/Panel/Layout/ControlsPage/Scroll/List
@onready var controls_reset: Button = $Dim/Panel/Layout/ControlsPage/Buttons/Reset
@onready var controls_back: Button = $Dim/Panel/Layout/ControlsPage/Buttons/Back
@onready var hint_label: Label = $Dim/Panel/Layout/Hint
@onready var close_button: Button = $Dim/Panel/Layout/Close

var _syncing := false
var _waiting_action: StringName
var _waiting_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sounds_slider.value_changed.connect(_on_sounds_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vsync_check.toggled.connect(_on_vsync_toggled)
	autosave_check.toggled.connect(_on_autosave_toggled)
	weather_effects_check.toggled.connect(_on_weather_effects_toggled)
	reduced_motion_check.toggled.connect(_on_reduced_motion_toggled)
	support_export.pressed.connect(_export_support_bundle)
	support_open.pressed.connect(_open_support_folder)
	var support_available := SupportBundle.is_supported()
	support_export.disabled = not support_available
	support_open.visible = support_available
	accessibility_button.pressed.connect(_show_accessibility.bind(true))
	accessibility_back.pressed.connect(_show_accessibility.bind(false))
	_build_language_selector()
	language_select.item_selected.connect(_on_language_selected)
	controls_button.pressed.connect(_show_controls.bind(true))
	controls_reset.pressed.connect(_reset_controls)
	controls_back.pressed.connect(_show_controls.bind(false))
	close_button.pressed.connect(close)
	GameSettings.changed.connect(_sync_from_settings)

func open() -> void:
	_waiting_action = &""
	_waiting_button = null
	_show_controls(false)
	_sync_from_settings()
	visible = true
	controls_button.grab_focus()

func close() -> void:
	if not visible:
		return
	_waiting_action = &""
	_waiting_button = null
	visible = false
	closed.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if _waiting_action != &"" and event is InputEventKey and event.pressed and not event.echo:
		var key_event := event as InputEventKey
		var key := key_event.physical_keycode if key_event.physical_keycode != KEY_NONE else key_event.keycode
		if key == KEY_ESCAPE:
			_cancel_rebind()
		else:
			GameSettings.set_key_binding(_waiting_action, key)
			_waiting_action = &""
			_waiting_button = null
			_rebuild_controls()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("ui_cancel"):
		if controls_page.visible:
			_show_controls(false)
		elif accessibility_page.visible:
			_show_accessibility(false)
		else:
			close()
		get_viewport().set_input_as_handled()

func _sync_from_settings() -> void:
	_syncing = true
	master_slider.value = GameSettings.master_volume * 100.0
	music_slider.value = GameSettings.music_volume * 100.0
	sounds_slider.value = GameSettings.sounds_volume * 100.0
	fullscreen_check.button_pressed = GameSettings.fullscreen
	vsync_check.button_pressed = GameSettings.vsync
	autosave_check.button_pressed = GameSettings.autosave
	weather_effects_check.button_pressed = GameSettings.weather_effects
	reduced_motion_check.button_pressed = GameSettings.reduced_motion
	_select_current_language()
	_syncing = false
	if controls_page.visible:
		_rebuild_controls()

func _build_language_selector() -> void:
	language_select.clear()
	for locale_id: String in GameSettings.get_supported_locales():
		var index := language_select.item_count
		language_select.add_item(GameSettings.get_locale_display_name(locale_id))
		language_select.set_item_metadata(index, locale_id)
	_select_current_language()

func _select_current_language() -> void:
	for index in range(language_select.item_count):
		if String(language_select.get_item_metadata(index)) == GameSettings.locale:
			language_select.select(index)
			return

func _on_language_selected(index: int) -> void:
	if _syncing or index < 0 or index >= language_select.item_count:
		return
	GameSettings.set_locale(String(language_select.get_item_metadata(index)))

func _show_controls(show: bool) -> void:
	_waiting_action = &""
	_waiting_button = null
	master_row.visible = not show
	music_row.visible = not show
	sounds_row.visible = not show
	fullscreen_check.visible = not show
	vsync_check.visible = not show
	autosave_check.visible = not show
	language_row.visible = not show
	accessibility_button.visible = not show
	controls_button.visible = not show
	accessibility_page.visible = false
	hint_label.visible = not show
	controls_page.visible = show
	if show:
		_rebuild_controls()
		controls_back.grab_focus()
	else:
		controls_button.grab_focus()

func _show_accessibility(show: bool) -> void:
	_waiting_action = &""
	_waiting_button = null
	master_row.visible = not show
	music_row.visible = not show
	sounds_row.visible = not show
	fullscreen_check.visible = not show
	vsync_check.visible = not show
	autosave_check.visible = not show
	language_row.visible = not show
	accessibility_button.visible = not show
	controls_button.visible = not show
	hint_label.visible = not show
	controls_page.visible = false
	accessibility_page.visible = show
	if show:
		weather_effects_check.grab_focus()
	else:
		accessibility_button.grab_focus()

func _rebuild_controls() -> void:
	for child: Node in controls_list.get_children():
		child.queue_free()
	for action: StringName in GameSettings.get_rebindable_actions():
		var row := HBoxContainer.new()
		var label := Label.new()
		label.text = GameSettings.get_control_label(action)
		label.custom_minimum_size = Vector2(132, 0)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var button := Button.new()
		button.text = GameSettings.get_key_binding_text(action)
		button.custom_minimum_size = Vector2(92, 0)
		button.pressed.connect(_begin_rebind.bind(action, button))
		row.add_child(label)
		row.add_child(button)
		controls_list.add_child(row)

func _begin_rebind(action: StringName, button: Button) -> void:
	_waiting_action = action
	_waiting_button = button
	button.text = tr("Press a key...")
	button.grab_focus()

func _cancel_rebind() -> void:
	if _waiting_button != null and _waiting_action != &"":
		_waiting_button.text = GameSettings.get_key_binding_text(_waiting_action)
	_waiting_action = &""
	_waiting_button = null

func _reset_controls() -> void:
	GameSettings.reset_controls()
	_rebuild_controls()
	controls_reset.grab_focus()

func _on_master_changed(value: float) -> void:
	if not _syncing:
		GameSettings.set_master_volume(value / 100.0)

func _on_music_changed(value: float) -> void:
	if not _syncing:
		GameSettings.set_music_volume(value / 100.0)

func _on_sounds_changed(value: float) -> void:
	if not _syncing:
		GameSettings.set_sounds_volume(value / 100.0)

func _on_fullscreen_toggled(value: bool) -> void:
	if not _syncing:
		GameSettings.set_fullscreen(value)

func _on_vsync_toggled(value: bool) -> void:
	if not _syncing:
		GameSettings.set_vsync(value)

func _on_autosave_toggled(value: bool) -> void:
	if not _syncing:
		GameSettings.set_autosave(value)

func _on_weather_effects_toggled(value: bool) -> void:
	if not _syncing:
		GameSettings.set_weather_effects(value)

func _on_reduced_motion_toggled(value: bool) -> void:
	if not _syncing:
		GameSettings.set_reduced_motion(value)

func _export_support_bundle() -> void:
	var path := SupportBundle.create_bundle()
	if path.is_empty():
		GameEvents.toast("Support bundle could not be created")
	else:
		GameEvents.toastf("Support bundle created: %s", [path.get_file()])
	support_export.grab_focus()

func _open_support_folder() -> void:
	var absolute := SupportBundle.get_output_directory_absolute()
	if not absolute.is_empty():
		OS.shell_open(absolute)
	support_open.grab_focus()
