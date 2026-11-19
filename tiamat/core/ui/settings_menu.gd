class_name SettingsMenu
extends CanvasLayer

## The settings every game shares (`GameSettings`): volume, display, autosave,
## text speed, language, accessibility and the game's controls, whose key or
## mouse button and gamepad button the player can rebind, under a heading for
## each group of controls a minigame reads (`ControlAction.group`). The left
## mouse button stays the pointer's: a click cancels a rebind. Its pages
## scroll inside one panel that fits the game's view; `ui_cancel` or Back
## leaves a page, then the menu.

signal closed

## The settings menu's name in `GameEvents.menu_opened` and `menu_closed`.
const MENU_ID := &"settings_menu"

enum Page { MAIN, ACCESSIBILITY, CONTROLS }

const PAGE_TITLES := {
	Page.MAIN: "Settings",
	Page.ACCESSIBILITY: "Accessibility",
	Page.CONTROLS: "Controls",
}
const HINT := "Settings are saved automatically."
const KEY_REBIND_HINT := "Press a key or mouse button. Esc or a left click cancels."
const BINDING_WIDTH := 76.0

@onready var title_label: Label = $Dim/Panel/Layout/Title
@onready var pages: ScrollContainer = $Dim/Panel/Layout/Pages
@onready var main_page: VBoxContainer = $Dim/Panel/Layout/Pages/Page/Main
@onready var master_slider: HSlider = $Dim/Panel/Layout/Pages/Page/Main/Master/Slider
@onready var music_slider: HSlider = $Dim/Panel/Layout/Pages/Page/Main/Music/Slider
@onready var sounds_slider: HSlider = $Dim/Panel/Layout/Pages/Page/Main/Sounds/Slider
@onready var fullscreen_check: CheckButton = $Dim/Panel/Layout/Pages/Page/Main/Fullscreen
@onready var vsync_check: CheckButton = $Dim/Panel/Layout/Pages/Page/Main/VSync
@onready var integer_scaling_check: CheckButton = $Dim/Panel/Layout/Pages/Page/Main/IntegerScaling
@onready var autosave_check: CheckButton = $Dim/Panel/Layout/Pages/Page/Main/Autosave
@onready var pause_on_focus_loss_check: CheckButton = $Dim/Panel/Layout/Pages/Page/Main/PauseOnFocusLoss
@onready var hints_check: CheckButton = $Dim/Panel/Layout/Pages/Page/Main/Hints
@onready var text_speed_select: OptionButton = $Dim/Panel/Layout/Pages/Page/Main/TextSpeed/Select
@onready var language_select: OptionButton = $Dim/Panel/Layout/Pages/Page/Main/Language/Select
@onready var online_services_check: CheckButton = $Dim/Panel/Layout/Pages/Page/Main/OnlineServices
@onready var accessibility_button: Button = $Dim/Panel/Layout/Pages/Page/Main/AccessibilityButton
@onready var controls_button: Button = $Dim/Panel/Layout/Pages/Page/Main/ControlsButton
@onready var reset_all_button: Button = $Dim/Panel/Layout/Pages/Page/Main/ResetAll
@onready var accessibility_page: VBoxContainer = $Dim/Panel/Layout/Pages/Page/Accessibility
@onready var weather_effects_check: CheckButton = $Dim/Panel/Layout/Pages/Page/Accessibility/WeatherEffects
@onready var reduced_motion_check: CheckButton = $Dim/Panel/Layout/Pages/Page/Accessibility/ReducedMotion
@onready var support_export: Button = $Dim/Panel/Layout/Pages/Page/Accessibility/ExportSupportBundle
@onready var support_open: Button = $Dim/Panel/Layout/Pages/Page/Accessibility/OpenSupportFolder
@onready var controls_page: VBoxContainer = $Dim/Panel/Layout/Pages/Page/Controls
@onready var controls_list: VBoxContainer = $Dim/Panel/Layout/Pages/Page/Controls/List
@onready var controls_reset: Button = $Dim/Panel/Layout/Pages/Page/Controls/Reset
@onready var hint_label: Label = $Dim/Panel/Layout/Hint
@onready var back_button: Button = $Dim/Panel/Layout/Back
@onready var confirm_reset: ConfirmationDialog = $ConfirmReset

var page := Page.MAIN
var _syncing := false
# The rebind under way: the action, whether it waits for a gamepad button
# rather than a key or mouse button, and the button that shows it.
var _waiting_action: StringName
var _waiting_gamepad := false
var _waiting_button: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sounds_slider.value_changed.connect(_on_sounds_changed)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)
	vsync_check.toggled.connect(_on_vsync_toggled)
	integer_scaling_check.toggled.connect(_on_integer_scaling_toggled)
	autosave_check.toggled.connect(_on_autosave_toggled)
	pause_on_focus_loss_check.toggled.connect(_on_pause_on_focus_loss_toggled)
	hints_check.toggled.connect(_on_hints_toggled)
	weather_effects_check.toggled.connect(_on_weather_effects_toggled)
	reduced_motion_check.toggled.connect(_on_reduced_motion_toggled)
	online_services_check.toggled.connect(_on_online_services_toggled)
	# A game without weather has no weather effects to turn off.
	weather_effects_check.visible = GameWeatherSystem.has_weather()
	support_export.pressed.connect(_export_support_bundle)
	support_open.pressed.connect(_open_support_folder)
	var support_available := SupportBundle.is_supported()
	support_export.disabled = not support_available
	support_open.visible = support_available
	accessibility_button.pressed.connect(show_page.bind(Page.ACCESSIBILITY))
	controls_button.pressed.connect(show_page.bind(Page.CONTROLS))
	reset_all_button.pressed.connect(confirm_reset.popup_centered)
	confirm_reset.confirmed.connect(_reset_all)
	for speed_name: String in GameSettings.TEXT_SPEED_NAMES:
		text_speed_select.add_item(speed_name)
	text_speed_select.item_selected.connect(_on_text_speed_selected)
	_build_language_selector()
	language_select.item_selected.connect(_on_language_selected)
	_build_controls()
	controls_reset.pressed.connect(_reset_controls)
	back_button.pressed.connect(go_back)
	GameSettings.changed.connect(_on_settings_changed)
	# The gamepad's buttons are named as the pad in use names them.
	InputPrompts.input_method_changed.connect(_on_settings_changed.unbind(1))

func open() -> void:
	_sync_from_settings()
	var opened := not visible
	visible = true
	show_page(Page.MAIN)
	if opened:
		GameEvents.menu_opened.emit(MENU_ID)

func close() -> void:
	if not visible:
		return
	_cancel_rebind()
	confirm_reset.hide()
	visible = false
	GameEvents.menu_closed.emit(MENU_ID)
	closed.emit()

## Leaves the page that is open, or the menu from the main page.
func go_back() -> void:
	if page == Page.MAIN:
		close()
		return
	var left := page
	show_page(Page.MAIN)
	(accessibility_button if left == Page.ACCESSIBILITY else controls_button).grab_focus()

func show_page(next: Page) -> void:
	_cancel_rebind()
	page = next
	main_page.visible = next == Page.MAIN
	accessibility_page.visible = next == Page.ACCESSIBILITY
	controls_page.visible = next == Page.CONTROLS
	# Labels translate their own text, now and when the language changes.
	title_label.text = PAGE_TITLES[next]
	hint_label.text = HINT
	pages.scroll_vertical = 0
	match next:
		Page.MAIN:
			master_slider.grab_focus()
		Page.ACCESSIBILITY:
			(weather_effects_check if weather_effects_check.visible else reduced_motion_check).grab_focus()
		Page.CONTROLS:
			var first := _first_binding_button()
			(first if first != null else controls_reset).grab_focus()

# A rebind reads the next key, mouse button or gamepad button before the
# focused button can take it as a press.
func _input(event: InputEvent) -> void:
	if not visible or _waiting_action == &"":
		return
	if event is InputEventKey or event is InputEventMouseButton:
		if not event.is_pressed() or event.is_echo():
			return
		var binding := ControlBindings.binding_of(event)
		var cancels: bool = binding == {"key": int(KEY_ESCAPE)} or binding == {"mouse": int(MOUSE_BUTTON_LEFT)}
		if cancels or _waiting_gamepad or binding.is_empty():
			_cancel_rebind()
		else:
			_finish_rebind(GameSettings.bind_control(_waiting_action, binding), ControlBindings.binding_text(binding))
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton or event is InputEventJoypadMotion:
		if event is InputEventJoypadButton and event.pressed:
			var button := (event as InputEventJoypadButton).button_index
			if _waiting_gamepad:
				_finish_rebind(GameSettings.bind_gamepad_button(_waiting_action, button), InputPrompts.get_button_name(button))
			else:
				_cancel_rebind()
		# No stick or button moves the focus off the rebind.
		get_viewport().set_input_as_handled()

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel") and not confirm_reset.visible:
		go_back()
		get_viewport().set_input_as_handled()

# A change shows at once while the menu is open; a closed menu reads the
# settings as it opens.
func _on_settings_changed() -> void:
	if visible:
		_sync_from_settings()

func _sync_from_settings() -> void:
	_syncing = true
	master_slider.value = GameSettings.master_volume * 100.0
	music_slider.value = GameSettings.music_volume * 100.0
	sounds_slider.value = GameSettings.sounds_volume * 100.0
	fullscreen_check.button_pressed = GameSettings.fullscreen
	vsync_check.button_pressed = GameSettings.vsync
	integer_scaling_check.button_pressed = GameSettings.integer_scaling
	autosave_check.button_pressed = GameSettings.autosave
	pause_on_focus_loss_check.button_pressed = GameSettings.pause_on_focus_loss
	hints_check.button_pressed = GameSettings.hints
	text_speed_select.select(GameSettings.text_speed)
	weather_effects_check.button_pressed = GameSettings.weather_effects
	reduced_motion_check.button_pressed = GameSettings.reduced_motion
	# Offered only while the game uses a service that goes online.
	online_services_check.visible = GameSettings.uses_online_services()
	online_services_check.button_pressed = GameSettings.online_services
	_select_current_language()
	_syncing = false
	if _waiting_action == &"":
		_refresh_controls()

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

# One row per rebindable control: its name, its key or mouse button and, when
# it has one, its gamepad button. The world's controls come first, then each
# group's under its heading. The controls are the game's, so the rows are
# built once.
func _build_controls() -> void:
	var bindings := GameSettings.bindings
	var groups: Array[String] = [""]
	for action: StringName in bindings.get_rebindable_actions():
		if not groups.has(bindings.get_control(action).group):
			groups.append(bindings.get_control(action).group)
	for group: String in groups:
		if not group.is_empty():
			var heading := Label.new()
			# Labels translate their own text, now and when the language changes.
			heading.text = group
			heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			controls_list.add_child(heading)
		for action: StringName in bindings.get_rebindable_actions():
			if bindings.get_control(action).group == group:
				controls_list.add_child(_control_row(action))

func _control_row(action: StringName) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.set_meta(&"action", action)
	var label := Label.new()
	# The name is translated by the layer that declares the control, and set
	# again when the language changes.
	label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = GameSettings.bindings.get_label(action)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	row.add_child(label)
	row.add_child(_binding_button(action, false))
	if GameSettings.bindings.has_gamepad_binding(action):
		row.add_child(_binding_button(action, true))
	else:
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(BINDING_WIDTH, 0)
		row.add_child(spacer)
	return row

# Shows each control's name and current bindings, in the current language.
func _refresh_controls() -> void:
	for row: Node in controls_list.get_children():
		if not row.has_meta(&"action"):
			continue
		var action: StringName = row.get_meta(&"action")
		(row.get_child(0) as Label).text = GameSettings.bindings.get_label(action)
		(row.get_child(1) as Button).text = _binding_text(action, false)
		var gamepad := row.get_child(2) as Button
		if gamepad != null:
			gamepad.text = _binding_text(action, true)

func _binding_button(action: StringName, gamepad: bool) -> Button:
	var button := Button.new()
	button.text = _binding_text(action, gamepad)
	button.custom_minimum_size = Vector2(BINDING_WIDTH, 0)
	button.clip_text = true
	button.pressed.connect(_begin_rebind.bind(action, gamepad, button))
	return button

func _binding_text(action: StringName, gamepad: bool) -> String:
	var bindings := GameSettings.bindings
	return InputPrompts.get_button_name(bindings.get_gamepad_button(action)) if gamepad else bindings.get_binding_text(action)

func _first_binding_button() -> Button:
	for row: Node in controls_list.get_children():
		for child: Node in row.get_children():
			if child is Button:
				return child as Button
	return null

func _begin_rebind(action: StringName, gamepad: bool, button: Button) -> void:
	_cancel_rebind()
	_waiting_action = action
	_waiting_gamepad = gamepad
	_waiting_button = button
	button.text = "Press a button..." if gamepad else "Press a key..."
	hint_label.text = "Esc cancels" if gamepad else KEY_REBIND_HINT
	button.grab_focus()

func _finish_rebind(bound: bool, input_name: String) -> void:
	_waiting_action = &""
	_waiting_button = null
	_refresh_controls()
	hint_label.text = HINT if bound else tr("%s is held by another control") % input_name

func _cancel_rebind() -> void:
	if _waiting_action != &"" and is_instance_valid(_waiting_button):
		_waiting_button.text = _binding_text(_waiting_action, _waiting_gamepad)
		hint_label.text = HINT
	_waiting_action = &""
	_waiting_button = null

func _reset_controls() -> void:
	GameSettings.reset_controls()
	controls_reset.grab_focus()

func _reset_all() -> void:
	GameSettings.reset_all()
	reset_all_button.grab_focus()

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

func _on_integer_scaling_toggled(value: bool) -> void:
	if not _syncing:
		GameSettings.set_integer_scaling(value)

func _on_autosave_toggled(value: bool) -> void:
	if not _syncing:
		GameSettings.set_autosave(value)

func _on_pause_on_focus_loss_toggled(value: bool) -> void:
	if not _syncing:
		GameSettings.set_pause_on_focus_loss(value)

func _on_hints_toggled(value: bool) -> void:
	if not _syncing:
		GameSettings.set_hints(value)

func _on_text_speed_selected(index: int) -> void:
	if not _syncing:
		GameSettings.set_text_speed(index as GameSettingsService.TextSpeed)

func _on_weather_effects_toggled(value: bool) -> void:
	if not _syncing:
		GameSettings.set_weather_effects(value)

func _on_reduced_motion_toggled(value: bool) -> void:
	if not _syncing:
		GameSettings.set_reduced_motion(value)

func _on_online_services_toggled(value: bool) -> void:
	if not _syncing:
		GameSettings.set_online_services(value)

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
