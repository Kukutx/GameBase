extends GutTest

const TEST_PATH := "user://game_settings_test.cfg"

func _read_project_version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", "unknown"))

func after_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
	GameSettings.apply()

func test_supported_locale_translation_and_selector() -> void:
	assert_eq(GameSettings.get_supported_locales(), PackedStringArray(["en", "zh_CN"]))
	var previous := TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	assert_eq(TranslationServer.translate("Settings"), "设置")
	assert_eq(TranslationServer.translate("Quick Save"), "快速保存")
	assert_eq(TranslationServer.translate("Autosave"), "自动保存")
	assert_eq(TranslationServer.translate("Spring"), "春季")
	assert_eq(TranslationServer.translate("Rain"), "下雨")
	assert_eq(TranslationServer.translate("Starter Town"), "起始镇")
	assert_eq(TranslationServer.translate("Copper Pickaxe"), "铜镐")
	assert_eq(TranslationServer.translate("BITE! Press %s"), "上钩了！按 %s")
	TranslationServer.set_locale(previous)

	var scene := load("res://gamebase/core/ui/settings_menu.tscn") as PackedScene
	var menu := scene.instantiate() as SettingsMenu
	add_child_autofree(menu)
	await get_tree().process_frame
	var selector := menu.get_node("Dim/Panel/Layout/Language/Select") as OptionButton
	assert_eq(selector.item_count, GameSettings.get_supported_locales().size())
	var accessibility_button := menu.get_node("Dim/Panel/Layout/AccessibilityButton") as Button
	var accessibility_page := menu.get_node("Dim/Panel/Layout/AccessibilityPage") as VBoxContainer
	var weather_effects := menu.get_node("Dim/Panel/Layout/AccessibilityPage/WeatherEffects") as CheckButton
	var reduced_motion := menu.get_node("Dim/Panel/Layout/AccessibilityPage/ReducedMotion") as CheckButton
	assert_not_null(accessibility_button)
	assert_not_null(weather_effects)
	assert_not_null(reduced_motion)
	menu.open()
	menu.call("_show_accessibility", true)
	await get_tree().process_frame
	assert_true(accessibility_page.visible)
	assert_eq(get_viewport().gui_get_focus_owner(), weather_effects)
	menu.call("_show_accessibility", false)
	await get_tree().process_frame
	assert_false(accessibility_page.visible)
	assert_eq(get_viewport().gui_get_focus_owner(), accessibility_button)
	menu.close()

func test_title_screen_static_and_dynamic_labels_translate_in_runtime() -> void:
	var previous := TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	var scene := load("res://gamebase/core/ui/title_screen.tscn") as PackedScene
	var title := scene.instantiate() as GameTitleScreen
	add_child_autofree(title)
	await get_tree().process_frame
	var continue_button := title.get_node("Center/Menu/Continue") as Button
	var settings_button := title.get_node("Center/Menu/Settings") as Button
	assert_eq(TranslationServer.translate(continue_button.text), "继续游戏")
	assert_eq(TranslationServer.translate(settings_button.text), "设置")
	var version_label := title.get_node("Center/Menu/Version") as Label
	assert_eq(version_label.text, "v%s" % _read_project_version())
	var slots := title.get_node("Center/Menu/SaveSlot") as OptionButton
	assert_eq(slots.get_item_text(0), "存档位 1")
	TranslationServer.set_locale(previous)

func test_settings_controls_page_builds_all_rebindable_actions() -> void:
	var scene := load("res://gamebase/core/ui/settings_menu.tscn") as PackedScene
	var menu := scene.instantiate() as SettingsMenu
	add_child_autofree(menu)
	await get_tree().process_frame
	menu.open()
	menu.call("_show_controls", true)
	await get_tree().process_frame
	var list := menu.get_node("Dim/Panel/Layout/ControlsPage/Scroll/List")
	assert_eq(list.get_child_count(), GameSettings.get_rebindable_actions().size())
	menu.close()

func test_farm1_default_keys_and_their_swap() -> void:
	var settings := GameSettingsService.new()
	settings.settings_path = TEST_PATH
	add_child_autofree(settings)
	settings.reset_controls()
	assert_eq(settings.get_key_binding(&"interact"), KEY_E)
	assert_eq(settings.get_key_binding(&"use_tool"), KEY_F)
	assert_eq(settings.get_control(&"move_up").secondary_key, KEY_UP)
	assert_false(settings.set_key_binding(&"interact", KEY_UP), "the up arrow stays with moving up")
	assert_true(settings.set_key_binding(&"interact", KEY_F))
	assert_eq(settings.get_key_binding(&"use_tool"), KEY_E)

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

func test_input_prompts_name_farm1_gamepad_controls() -> void:
	var previous_gamepad := InputPrompts.using_gamepad
	InputPrompts.using_gamepad = true
	assert_eq(InputPrompts.get_action_prompt(&"interact"), "A")
	assert_eq(InputPrompts.get_action_prompt(&"use_tool"), "X")
	assert_eq(InputPrompts.get_action_prompt(&"hotbar_prev"), "LT")
	assert_eq(InputPrompts.get_action_prompt(&"hotbar_next"), "RT")
	InputPrompts.using_gamepad = previous_gamepad

func test_gamepad_triggers_cycle_hotbar_actions() -> void:
	var settings := GameSettingsService.new()
	settings.settings_path = TEST_PATH
	add_child_autofree(settings)
	settings.reset_controls()
	for action: StringName in [&"hotbar_prev", &"hotbar_next"]:
		var motions := 0
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventJoypadMotion:
				motions += 1
		assert_eq(motions, 1, "%s should have one trigger binding" % action)

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
