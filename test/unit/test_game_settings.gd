extends GutTest

const TEST_PATH := "user://game_settings_test.cfg"

func after_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	GameSettings.apply()

func test_settings_round_trip() -> void:
	var source := GameSettingsService.new()
	source.settings_path = TEST_PATH
	add_child_autofree(source)
	source.master_volume = 0.55
	source.music_volume = 0.35
	source.sounds_volume = 0.75
	source.fullscreen = true
	source.vsync = false
	source.locale = "zh_CN"
	source.save_settings()

	var restored := GameSettingsService.new()
	restored.settings_path = TEST_PATH
	add_child_autofree(restored)
	restored.load_settings()
	assert_almost_eq(restored.master_volume, 0.55, 0.001)
	assert_almost_eq(restored.music_volume, 0.35, 0.001)
	assert_almost_eq(restored.sounds_volume, 0.75, 0.001)
	assert_true(restored.fullscreen)
	assert_false(restored.vsync)
	assert_eq(restored.locale, "zh_CN")

func test_supported_locale_translation_and_selector() -> void:
	var previous := TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	assert_eq(TranslationServer.translate("Settings"), "设置")
	assert_eq(TranslationServer.translate("Quick Save"), "快速保存")
	TranslationServer.set_locale(previous)

	var scene := load("res://game/ui/settings_menu.tscn") as PackedScene
	var menu := scene.instantiate() as SettingsMenu
	add_child_autofree(menu)
	await get_tree().process_frame
	var selector := menu.get_node("Dim/Panel/Layout/Language/Select") as OptionButton
	assert_eq(selector.item_count, GameSettings.get_supported_locales().size())

func test_key_bindings_round_trip_and_apply_to_input_map() -> void:
	var source := GameSettingsService.new()
	source.settings_path = TEST_PATH
	add_child_autofree(source)
	assert_true(source.set_key_binding(&"interact", KEY_Q))
	assert_eq(source.get_key_binding(&"interact"), KEY_Q)
	var has_q := false
	for event: InputEvent in InputMap.action_get_events(&"interact"):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == KEY_Q:
			has_q = true
	assert_true(has_q)

	var restored := GameSettingsService.new()
	restored.settings_path = TEST_PATH
	add_child_autofree(restored)
	assert_eq(restored.get_key_binding(&"interact"), KEY_Q)
	assert_eq(restored.get_key_binding_text(&"interact"), OS.get_keycode_string(KEY_Q))

func test_duplicate_primary_key_swaps_existing_binding() -> void:
	var settings := GameSettingsService.new()
	settings.settings_path = TEST_PATH
	add_child_autofree(settings)
	settings.reset_controls()
	assert_eq(settings.get_key_binding(&"interact"), KEY_E)
	assert_eq(settings.get_key_binding(&"use_tool"), KEY_F)
	assert_true(settings.set_key_binding(&"interact", KEY_F))
	assert_eq(settings.get_key_binding(&"interact"), KEY_F)
	assert_eq(settings.get_key_binding(&"use_tool"), KEY_E)

func test_settings_controls_page_builds_all_rebindable_actions() -> void:
	var scene := load("res://game/ui/settings_menu.tscn") as PackedScene
	var menu := scene.instantiate() as SettingsMenu
	add_child_autofree(menu)
	await get_tree().process_frame
	menu.open()
	menu.call("_show_controls", true)
	await get_tree().process_frame
	var list := menu.get_node("Dim/Panel/Layout/ControlsPage/Scroll/List")
	assert_eq(list.get_child_count(), GameSettings.get_control_actions().size())
	menu.close()

func test_keyboard_rebinding_preserves_gamepad_core_actions() -> void:
	var settings := GameSettingsService.new()
	settings.settings_path = TEST_PATH
	add_child_autofree(settings)
	settings.reset_controls()
	assert_true(settings.set_key_binding(&"interact", KEY_Q))

	var expected_buttons := {
		&"interact": JOY_BUTTON_A,
		&"use_tool": JOY_BUTTON_X,
		&"give_gift": JOY_BUTTON_Y,
		&"remove_building": JOY_BUTTON_RIGHT_SHOULDER,
		&"open_menu": JOY_BUTTON_START,
		&"quick_save": JOY_BUTTON_LEFT_STICK,
		&"quick_load": JOY_BUTTON_RIGHT_STICK,
	}
	for action: StringName in expected_buttons:
		var found := false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == expected_buttons[action]:
				found = true
				break
		assert_true(found, "%s missing default gamepad button" % action)

func test_rebindable_movement_keeps_gamepad_axis_and_dpad_support() -> void:
	var settings := GameSettingsService.new()
	settings.settings_path = TEST_PATH
	add_child_autofree(settings)
	settings.reset_controls()
	for action: StringName in [&"move_left", &"move_right", &"move_up", &"move_down"]:
		var has_button := false
		var has_motion := false
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadButton:
				has_button = true
			elif event is InputEventJoypadMotion:
				has_motion = true
		assert_true(has_button, "%s missing D-Pad support" % action)
		assert_true(has_motion, "%s missing analog-stick support" % action)
