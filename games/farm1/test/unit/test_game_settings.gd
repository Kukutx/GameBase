extends GutTest

const TEST_PATH := "user://game_settings_test.cfg"

func _read_project_version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", "unknown"))

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
	source.autosave = false
	source.weather_effects = false
	source.reduced_motion = true
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
	assert_false(restored.autosave)
	assert_false(restored.weather_effects)
	assert_true(restored.reduced_motion)
	assert_eq(restored.locale, "zh_CN")

func test_supported_locale_translation_and_selector() -> void:
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

	var scene := load("res://game/ui/settings_menu.tscn") as PackedScene
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
	var scene := load("res://game/ui/title_screen.tscn") as PackedScene
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

func test_a_key_another_control_holds_fixed_cannot_be_bound() -> void:
	var settings := GameSettingsService.new()
	settings.settings_path = TEST_PATH
	add_child_autofree(settings)
	settings.reset_controls()
	assert_eq(settings.get_control(&"move_up").secondary_key, KEY_UP)
	assert_false(settings.set_key_binding(&"interact", KEY_UP), "the up arrow stays with moving up")
	assert_eq(settings.get_key_binding(&"interact"), KEY_E)
	assert_true(settings.set_key_binding(&"move_up", KEY_UP), "a control may take its own second key")

func test_settings_controls_page_builds_all_rebindable_actions() -> void:
	var scene := load("res://game/ui/settings_menu.tscn") as PackedScene
	var menu := scene.instantiate() as SettingsMenu
	add_child_autofree(menu)
	await get_tree().process_frame
	menu.open()
	menu.call("_show_controls", true)
	await get_tree().process_frame
	var list := menu.get_node("Dim/Panel/Layout/ControlsPage/Scroll/List")
	assert_eq(list.get_child_count(), GameSettings.get_rebindable_actions().size())
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

func test_input_prompts_follow_active_device_and_rebinding() -> void:
	var previous_gamepad := InputPrompts.using_gamepad
	InputPrompts.using_gamepad = false
	assert_eq(InputPrompts.get_action_prompt(&"interact"), GameSettings.get_key_binding_text(&"interact"))
	InputPrompts.using_gamepad = true
	assert_eq(InputPrompts.get_action_prompt(&"interact"), "A")
	assert_eq(InputPrompts.get_action_prompt(&"use_tool"), "X")
	assert_eq(InputPrompts.get_action_prompt(&"hotbar_prev"), "LT")
	assert_eq(InputPrompts.get_action_prompt(&"hotbar_next"), "RT")
	InputPrompts.using_gamepad = previous_gamepad

func test_languages_are_the_source_and_every_registered_translation() -> void:
	assert_eq(GameSettings.get_supported_locales(), PackedStringArray(["en", "zh_CN"]))
	assert_eq(GameSettings.get_locale_display_name("en"), "English")
	assert_eq(GameSettings.get_locale_display_name("zh_CN"), "简体中文")
	var settings := GameSettingsService.new()
	settings.settings_path = TEST_PATH
	add_child_autofree(settings)
	settings.set_locale("fr")
	assert_eq(settings.locale, "en", "a language the game does not ship falls back to the source")

func test_core_controls_follow_the_game_and_a_game_control_replaces_one() -> void:
	var jump := ControlAction.new()
	jump.action = &"jump"
	jump.display_name = "Jump"
	jump.key = KEY_SPACE
	var save := ControlAction.new()
	save.action = &"quick_save"
	save.display_name = "Save"
	save.key = KEY_F5
	var controls: Array[ControlAction] = [jump, save]
	var actions: Array[StringName] = []
	for control: ControlAction in GameSettingsService.resolve_controls(controls):
		actions.append(control.action)
	var expected: Array[StringName] = [&"jump", &"quick_save", &"interact", &"quick_load"]
	assert_eq(actions, expected)
	assert_eq(GameSettingsService.find_control_problems(controls), PackedStringArray())

func test_control_problems_name_the_control() -> void:
	var nameless := ControlAction.new()
	nameless.action = &"dash"
	nameless.key = KEY_SHIFT
	var keyless := ControlAction.new()
	keyless.action = &"block"
	keyless.display_name = "Block"
	var clash := ControlAction.new()
	clash.action = &"talk"
	clash.display_name = "Talk"
	clash.key = KEY_E
	var unbound := ControlAction.new()
	unbound.action = &"emote"
	unbound.rebindable = false
	var second := ControlAction.new()
	second.action = &"dodge"
	second.display_name = "Dodge"
	second.key = KEY_Z
	second.secondary_key = KEY_K
	var controls: Array[ControlAction] = [nameless, keyless, clash, unbound, clash, second, null]
	var problems := GameSettingsService.find_control_problems(controls)
	for expected: String in [
		"GameDefinition.controls has an entry that is not a ControlAction",
		"rebindable control 'dash' has no display name",
		"rebindable control 'block' has no default key",
		"control 'block' has no key, button or axis",
		"control 'emote' has no key, button or axis",
		"control 'talk' is listed twice",
		"controls 'talk' and 'interact' share the default key E",
		"controls 'dodge' and 'quick_save' share the default key K",
	]:
		assert_has(problems, expected)

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
