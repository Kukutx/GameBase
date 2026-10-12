extends GutTest

## The core's menus: the project theme they draw with, the settings pages and
## their rebinding, the pause menu's questions, and that each fits the view.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const MenuFit := preload("res://gamebase/core/test/menu_fit.gd")
const TEST_DIRECTORY := "user://test_menus"

var _save_directory := ""

func before_each() -> void:
	_save_directory = SaveManager.save_directory
	SaveManager.save_directory = TEST_DIRECTORY
	SaveManager.select_slot(SaveManager.active_slot)
	SaveManager.delete_save()

func after_each() -> void:
	SaveManager.delete_save()
	SaveManager.save_directory = _save_directory
	SaveManager.select_slot(SaveManager.active_slot)
	GameSettings.reset_all()
	InputLock.clear()
	var focus := get_viewport().gui_get_focus_owner()
	if focus != null:
		focus.release_focus()

func test_every_menu_draws_with_the_project_theme() -> void:
	var path := String(ProjectSettings.get_setting("gui/theme/custom", ""))
	assert_false(path.is_empty(), "the game sets its theme in project.godot")
	assert_true(load(path) is Theme)
	assert_eq(ThemeDB.get_project_theme().resource_path, path)

func test_the_music_and_sounds_buses_send_to_master() -> void:
	for bus: StringName in GameSettingsService.AUDIO_BUSES:
		var index := AudioServer.get_bus_index(bus)
		assert_gt(index, 0, "%s exists beside Master" % bus)
		assert_eq(AudioServer.get_bus_send(index), &"Master")

func test_the_settings_pages_open_from_the_main_page_and_lead_back() -> void:
	var menu := _settings()
	menu.open()
	assert_true(menu.main_page.visible)
	assert_eq(_focus(), menu.master_slider)
	menu.controls_button.pressed.emit()
	assert_true(menu.controls_page.visible)
	assert_false(menu.main_page.visible)
	assert_eq(menu.title_label.text, "Controls")
	assert_eq(_rows(menu).size(), GameSettings.bindings.get_rebindable_actions().size())
	menu.go_back()
	assert_true(menu.main_page.visible)
	assert_eq(menu.title_label.text, "Settings")
	assert_eq(_focus(), menu.controls_button, "back on the button that opened the page")
	watch_signals(menu)
	menu.go_back()
	assert_false(menu.visible)
	assert_signal_emit_count(menu, "closed", 1)

func test_a_key_and_a_gamepad_button_are_rebound_on_the_controls_page() -> void:
	var menu := _settings()
	menu.open()
	menu.show_page(SettingsMenu.Page.CONTROLS)
	var key_button := _binding(menu, &"interact", 1)
	key_button.pressed.emit()
	assert_eq(key_button.text, "Press a key...")
	menu._input(_key(KEY_O))
	assert_eq(GameSettings.bindings.get_binding(&"interact"), {"key": int(KEY_O)})
	key_button = _binding(menu, &"interact", 1)
	assert_eq(key_button.text, "O")
	assert_eq(_focus(), key_button, "the rebound button keeps the focus")

	_binding(menu, &"interact", 2).pressed.emit()
	menu._input(_key(KEY_P))
	assert_eq(GameSettings.bindings.get_binding(&"interact"), {"key": int(KEY_O)}, "a key does not bind a gamepad button")
	_binding(menu, &"interact", 2).pressed.emit()
	menu._input(_pad(JOY_BUTTON_Y))
	assert_eq(GameSettings.bindings.get_gamepad_button(&"interact"), JOY_BUTTON_Y)
	assert_eq(_binding(menu, &"interact", 2).text, "Y")
	assert_true(_has_button_event(&"interact", JOY_BUTTON_Y))
	assert_false(_has_button_event(&"interact", GameSettings.bindings.get_control(&"interact").gamepad_button))

func test_a_mouse_button_is_bound_and_a_left_click_cancels() -> void:
	var menu := _settings()
	menu.open()
	menu.show_page(SettingsMenu.Page.CONTROLS)
	var bound := GameSettings.bindings.get_binding(&"interact")
	_binding(menu, &"interact", 1).pressed.emit()
	menu._input(_click(MOUSE_BUTTON_LEFT))
	assert_eq(GameSettings.bindings.get_binding(&"interact"), bound, "the left button stays the pointer's")
	assert_eq(_binding(menu, &"interact", 1).text, ControlBindings.binding_text(bound))
	_binding(menu, &"interact", 1).pressed.emit()
	assert_eq(menu.hint_label.text, SettingsMenu.KEY_REBIND_HINT)
	menu._input(_click(MOUSE_BUTTON_XBUTTON1))
	assert_eq(GameSettings.bindings.get_binding(&"interact"), {"mouse": int(MOUSE_BUTTON_XBUTTON1)})
	assert_eq(_binding(menu, &"interact", 1).text, "Mouse Back")
	assert_eq(InputPrompts.get_action_prompt(&"interact"), "Mouse Back")
	var pressed := InputEventMouseButton.new()
	pressed.button_index = MOUSE_BUTTON_XBUTTON1
	pressed.pressed = true
	assert_true(pressed.is_action_pressed(&"interact"), "the input map takes the mouse button")

func test_the_controls_page_follows_a_change_of_language() -> void:
	var menu := _settings()
	menu.open()
	menu.show_page(SettingsMenu.Page.CONTROLS)
	var label := _binding(menu, &"interact", 1).get_parent().get_child(0) as Label
	assert_eq(label.text, "Interact")
	GameSettings.set_locale("zh_CN")
	var translated := label.text
	var expected := TranslationServer.translate("Interact")
	GameSettings.set_locale(GameSettingsService.SOURCE_LOCALE)
	assert_eq(translated, expected)
	assert_ne(translated, "Interact")
	assert_eq(label.text, "Interact", "and back")

func test_each_group_of_controls_shows_under_its_heading() -> void:
	var menu := _settings()
	var heading := ""
	for child: Node in menu.controls_list.get_children():
		if child.has_meta(&"action"):
			assert_eq(GameSettings.bindings.get_control(child.get_meta(&"action")).group, heading, "%s under its group" % child.get_meta(&"action"))
		else:
			heading = (child as Label).text
			assert_ne(heading, "", "a heading names its group")

func test_escape_cancels_a_rebind() -> void:
	var menu := _settings()
	menu.open()
	menu.show_page(SettingsMenu.Page.CONTROLS)
	var bound := GameSettings.bindings.get_binding_text(&"interact")
	_binding(menu, &"interact", 1).pressed.emit()
	menu._input(_key(KEY_ESCAPE))
	assert_eq(_binding(menu, &"interact", 1).text, bound)
	assert_eq(GameSettings.bindings.get_binding_text(&"interact"), bound)
	assert_true(menu.visible, "Escape ends the rebind, not the menu")

func test_reset_all_asks_then_restores_every_setting_but_the_language() -> void:
	var menu := _settings()
	menu.open()
	var locales := GameSettings.get_supported_locales()
	var language := locales[locales.size() - 1]
	GameSettings.set_master_volume(0.2)
	GameSettings.set_integer_scaling(true)
	GameSettings.set_pause_on_focus_loss(false)
	GameSettings.bind_control(&"interact", {"key": int(KEY_O)})
	GameSettings.bind_gamepad_button(&"interact", JOY_BUTTON_Y)
	GameSettings.set_locale(language)
	assert_eq(get_tree().root.content_scale_stretch, Window.CONTENT_SCALE_STRETCH_INTEGER)
	menu.reset_all_button.pressed.emit()
	assert_true(menu.confirm_reset.visible, "it asks first")
	assert_almost_eq(GameSettings.master_volume, 0.2, 0.001)
	# The dialog closes as its OK button confirms.
	menu.confirm_reset.hide()
	menu.confirm_reset.confirmed.emit()
	assert_eq(GameSettings.master_volume, 1.0)
	assert_eq(menu.master_slider.value, 100.0)
	assert_false(GameSettings.integer_scaling)
	assert_eq(get_tree().root.content_scale_stretch, Window.CONTENT_SCALE_STRETCH_FRACTIONAL)
	assert_true(GameSettings.pause_on_focus_loss)
	var interact := GameSettings.bindings.get_control(&"interact")
	assert_eq(GameSettings.bindings.get_binding(&"interact"), interact.get_default_binding())
	assert_eq(GameSettings.bindings.get_gamepad_button(&"interact"), interact.gamepad_button)
	assert_eq(GameSettings.locale, language, "the language stays")
	GameSettings.set_locale(GameSettingsService.SOURCE_LOCALE)

func test_a_game_without_weather_shows_no_weather_toggle() -> void:
	var definition := GameDefinition.new()
	var menu: SettingsMenu = ContentFixture.with_definition(definition, _settings)
	assert_false(menu.weather_effects_check.visible)
	menu.open()
	menu.show_page(SettingsMenu.Page.ACCESSIBILITY)
	assert_eq(_focus(), menu.reduced_motion_check)
	menu.close()
	definition.clear_weather_id = &"fixture_clear"
	var with_weather: SettingsMenu = ContentFixture.with_definition(definition, _settings)
	assert_true(with_weather.weather_effects_check.visible)

func test_the_pause_menu_opens_when_the_window_loses_focus() -> void:
	var menu := _pause()
	menu.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(menu.visible)
	assert_true(get_tree().paused)
	menu.close()
	InputLock.lock(&"fixture_dialogue", true)
	menu.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(menu.visible, "a dialogue that pauses the world waits for the player as it is")
	InputLock.unlock(&"fixture_dialogue")
	GameSettings.set_pause_on_focus_loss(false)
	menu.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_false(menu.visible)

func test_loading_from_the_pause_menu_asks_first() -> void:
	var menu := _pause()
	menu.open()
	menu.load_button.pressed.emit()
	assert_eq(menu.status_label.text, "No save available")
	assert_false(menu.confirm_load.visible)

	_write_usable_save()
	menu.load_button.pressed.emit()
	assert_true(menu.confirm_load.visible, "a load asks before it throws away the progress")
	assert_false(SaveManager.is_restoring())
	menu.confirm_load.hide()
	menu.confirm_load.canceled.emit()
	assert_eq(_focus(), menu.load_button)

func test_the_pause_menu_loads_the_player_s_own_save_before_an_autosave() -> void:
	var menu := _pause()
	menu.open()
	_write_usable_save(true)
	assert_eq(PauseMenu.get_load_kind(), GameSaveManager.SaveKind.AUTO, "with no save of their own, the autosave")
	menu.request_load()
	assert_eq(menu.confirm_load.dialog_text, "Unsaved progress will be lost. Load the autosave?", "the question names what loads")
	menu.confirm_load.hide()
	_write_usable_save()
	assert_eq(PauseMenu.get_load_kind(), GameSaveManager.SaveKind.MANUAL)
	menu.request_load()
	assert_eq(menu.confirm_load.dialog_text, "Unsaved progress will be lost. Load your last save?")
	menu.confirm_load.hide()

func test_quick_load_opens_the_pause_menu_and_asks() -> void:
	_write_usable_save()
	var menu := _pause()
	var quick_load := InputEventAction.new()
	quick_load.action = &"quick_load"
	quick_load.pressed = true
	menu._unhandled_input(quick_load)
	assert_true(menu.visible)
	assert_true(menu.confirm_load.visible)
	assert_false(SaveManager.is_restoring())

func test_the_pause_control_opens_and_closes_the_pause_menu_and_cancel_only_closes_it() -> void:
	var menu := _pause()
	menu._unhandled_input(_action(&"ui_cancel"))
	assert_false(menu.visible, "B or Esc as cancel leaves the world be")
	menu._unhandled_input(_action(&"pause"))
	assert_true(menu.visible)
	assert_true(get_tree().paused)
	menu._unhandled_input(_action(&"pause"))
	assert_false(menu.visible, "pause again resumes")
	menu._unhandled_input(_action(&"pause"))
	menu._unhandled_input(_action(&"ui_cancel"))
	assert_false(menu.visible, "and so does cancel")
	assert_true(GameSettings.bind_control(&"pause", {"key": int(KEY_P)}))
	var key := _key(KEY_P)
	assert_true(key.is_action_pressed(&"pause"), "the player rebinds the pause key")
	assert_false(_key(KEY_ESCAPE).is_action_pressed(&"pause"))

func test_the_pause_menu_opens_when_the_gamepad_in_use_disconnects() -> void:
	var menu := _pause()
	InputPrompts.call("_use_gamepad", 4)
	Input.joy_connection_changed.emit(4, false)
	assert_true(menu.visible, "the world waits for the player to take up a pad again")
	assert_false(InputPrompts.using_gamepad)
	menu.close()
	InputLock.lock(&"fixture_menu", true)
	InputPrompts.call("_use_gamepad", 4)
	Input.joy_connection_changed.emit(4, false)
	assert_false(menu.visible, "a menu on top already waits for the player")
	InputLock.unlock(&"fixture_menu")

func test_quitting_from_the_pause_menu_asks_first() -> void:
	var menu := _pause()
	menu.open()
	assert_eq(menu.quit_button.visible, not OS.has_feature("web"))
	menu.quit_button.pressed.emit()
	assert_true(menu.confirm_quit.visible)
	menu.confirm_quit.hide()

func test_the_core_menus_and_their_questions_fit_the_view() -> void:
	var view := get_viewport().get_visible_rect()
	var base := Vector2(ProjectSettings.get_setting("display/window/size/viewport_width"), ProjectSettings.get_setting("display/window/size/viewport_height"))
	assert_eq(view.size, base, "the tests see the game's own view")
	var title := (load("res://gamebase/core/ui/title_screen.tscn") as PackedScene).instantiate() as GameTitleScreen
	add_child_autofree(title)
	await _layout()
	assert_eq(MenuFit.find_overflow(title, view), PackedStringArray(), "the title screen")
	for dialog: Window in [title.confirm_new_game, title.confirm_delete]:
		await _assert_window_fits(dialog, view)
	title.queue_free()

	var pause := _pause()
	pause.open()
	await _layout()
	assert_eq(MenuFit.find_overflow(pause, view), PackedStringArray(), "the pause menu")
	for dialog: Window in [pause.confirm_load, pause.confirm_title, pause.confirm_quit]:
		await _assert_window_fits(dialog, view)
	pause.settings_button.pressed.emit()
	var settings := pause.settings_menu
	for page: SettingsMenu.Page in SettingsMenu.Page.values():
		settings.show_page(page)
		await _layout()
		assert_eq(MenuFit.find_overflow(settings, view), PackedStringArray(), "settings page %s" % SettingsMenu.Page.keys()[page])
	await _assert_window_fits(settings.confirm_reset, view)

func _assert_window_fits(window: Window, view: Rect2) -> void:
	(window as Window).call("popup_centered")
	await _layout()
	assert_eq(MenuFit.find_window_overflow(window, view), "")
	window.hide()

func _layout() -> void:
	# Containers sort their children on the frame after a change.
	await get_tree().process_frame
	await get_tree().process_frame

func _settings() -> SettingsMenu:
	var menu := (load("res://gamebase/core/ui/settings_menu.tscn") as PackedScene).instantiate() as SettingsMenu
	add_child_autofree(menu)
	return menu

func _pause() -> PauseMenu:
	var menu := (load("res://gamebase/core/ui/pause_menu.tscn") as PackedScene).instantiate() as PauseMenu
	add_child_autofree(menu)
	return menu

func _focus() -> Control:
	return get_viewport().gui_get_focus_owner()

# The rows of the controls page, one per rebindable control.
static func _rows(menu: SettingsMenu) -> Array[Node]:
	return menu.controls_list.get_children().filter(func(child: Node) -> bool: return child.has_meta(&"action"))

static func _binding(menu: SettingsMenu, action: StringName, column: int) -> Button:
	for row: Node in _rows(menu):
		if row.get_meta(&"action") == action:
			return row.get_child(column) as Button
	return null

static func _action(action: StringName) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	return event

static func _click(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	return event

static func _key(key: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	return event

static func _pad(button: JoyButton) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return event

static func _has_button_event(action: StringName, button: JoyButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			return true
	return false

# A save of this build the slot can load, its own or its autosave: every
# section, the clock, and the game's start location.
func _write_usable_save(autosave := false) -> void:
	var data := {
		"version": GameSaveManager.SAVE_VERSION,
		"saved_at_unix_msec": Time.get_unix_time_from_system() * 1000.0,
	}
	for section: SaveSection in SaveManager.get("_sections"):
		data[String(section.id)] = {}
	data["place"] = {"location_id": String(GameDefinition.current().start_location_id)}
	data["clock"] = {"day": 1, "minute_of_day": 6 * 60}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIRECTORY))
	var file := FileAccess.open(String(SaveManager.get_slot_paths(SaveManager.active_slot, autosave)["save"]), FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()
	assert_true(SaveManager.has_save(), "the fixture save is one this build can load")
