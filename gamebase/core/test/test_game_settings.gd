extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const TEST_PATH := "user://game_settings_test.json"

## Input actions the fixture controls of a test added, erased after it.
var _fixture_actions: Array[StringName] = []

func after_each() -> void:
	# The services of the test write their last change first.
	await _frame_done()
	JsonFile.remove(TEST_PATH)
	for action: StringName in _fixture_actions:
		if InputMap.has_action(action):
			InputMap.erase_action(action)
	_fixture_actions.clear()
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
	source.text_speed = GameSettingsService.TextSpeed.FAST
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
	assert_eq(restored.text_speed, GameSettingsService.TextSpeed.FAST)
	assert_eq(restored.locale, "zh_CN")

func test_text_speed_sets_how_long_each_character_shows() -> void:
	var settings := GameSettingsService.new()
	settings.settings_path = TEST_PATH
	add_child_autofree(settings)
	assert_eq(settings.text_speed, GameSettingsService.TextSpeed.NORMAL, "the default")
	var seconds := settings.get_seconds_per_character()
	settings.set_text_speed(GameSettingsService.TextSpeed.SLOW)
	assert_gt(settings.get_seconds_per_character(), seconds)
	settings.set_text_speed(GameSettingsService.TextSpeed.FAST)
	assert_lt(settings.get_seconds_per_character(), seconds)
	assert_gt(settings.get_seconds_per_character(), 0.0)
	settings.set_text_speed(GameSettingsService.TextSpeed.INSTANT)
	assert_eq(settings.get_seconds_per_character(), 0.0, "a whole line at once")

	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"settings_version": GameSettingsService.SETTINGS_VERSION, "gameplay": {"text_speed": "warp"}}))
	file.close()
	settings.load_settings()
	assert_eq(settings.text_speed, GameSettingsService.TextSpeed.INSTANT, "an unknown speed keeps the current one")

func test_online_services_stay_off_until_the_player_allows_them_and_are_offered_while_a_module_uses_one() -> void:
	var source := GameSettingsService.new()
	source.settings_path = TEST_PATH
	add_child_autofree(source)
	assert_false(source.online_services, "off by default")
	assert_false(source.uses_online_services())
	var used := [false]
	source.register_online_service(&"fixture_chat", func() -> bool: return used[0])
	assert_false(source.uses_online_services(), "a service the game does not use now")
	used[0] = true
	assert_true(source.uses_online_services())
	source.set_online_services(true)
	await _frame_done()

	var restored := GameSettingsService.new()
	restored.settings_path = TEST_PATH
	add_child_autofree(restored)
	restored.load_settings()
	assert_true(restored.online_services)
	assert_false(restored.uses_online_services(), "a service is registered at run time, not saved")

func test_key_bindings_round_trip_and_apply_to_input_map() -> void:
	var source := _settings_with_controls([])
	assert_true(source.set_key_binding(&"interact", KEY_Q))
	assert_eq(source.get_key_binding(&"interact"), KEY_Q)
	assert_true(_has_key_event(&"interact", KEY_Q))
	await _frame_done()

	var restored := _settings_with_controls([])
	assert_eq(restored.get_key_binding(&"interact"), KEY_Q)
	assert_eq(restored.get_key_binding_text(&"interact"), OS.get_keycode_string(KEY_Q))

func test_the_changes_of_a_frame_are_written_once_it_is_done_and_whole() -> void:
	var settings := GameSettingsService.new()
	settings.settings_path = TEST_PATH
	add_child_autofree(settings)
	for step in 20:
		settings.set_master_volume(step / 20.0)
	settings.set_vsync(false)
	assert_false(FileAccess.file_exists(TEST_PATH), "a slider dragged across writes nothing while it moves")
	await _frame_done()
	assert_true(FileAccess.file_exists(TEST_PATH), "the frame's changes are written as it ends")
	assert_false(FileAccess.file_exists(TEST_PATH + ".tmp"), "written beside the file and then over it")
	var restored := GameSettingsService.new()
	restored.settings_path = TEST_PATH
	add_child_autofree(restored)
	assert_almost_eq(restored.master_volume, 0.95, 0.001, "the last value the slider had")
	assert_false(restored.vsync)

func test_settings_a_crash_left_beside_the_file_are_read() -> void:
	assert_eq(JsonFile.write(TEST_PATH + ".tmp", {"settings_version": GameSettingsService.SETTINGS_VERSION, "audio": {"music": 0.25}}), "")
	var settings := GameSettingsService.new()
	settings.settings_path = TEST_PATH
	add_child_autofree(settings)
	assert_almost_eq(settings.music_volume, 0.25, 0.001)

func test_the_bindings_answer_every_gamepad() -> void:
	var settings := _settings_with_controls([])
	var one_pad_only := {}
	for action: StringName in InputMap.get_actions():
		for event: InputEvent in InputMap.action_get_events(action):
			if (event is InputEventJoypadButton or event is InputEventJoypadMotion) and event.device != ControlAction.ALL_DEVICES:
				one_pad_only[action] = event.device
	assert_eq(one_pad_only, {}, "actions, the project's menu ones too, with a gamepad event of one device")
	for device: int in [0, 1, 3]:
		var press := InputEventJoypadButton.new()
		press.device = device
		press.button_index = settings.get_gamepad_binding(&"interact")
		press.pressed = true
		assert_true(press.is_action_pressed(&"interact"), "gamepad %d interacts" % device)

func test_a_key_that_is_not_a_whole_number_reads_as_the_default() -> void:
	var file := FileAccess.open(TEST_PATH, FileAccess.WRITE)
	file.store_string(JSON.stringify({"settings_version": GameSettingsService.SETTINGS_VERSION, "controls": {"interact": 81.5, "quick_save": 1e19, "quick_load": 81.0}}))
	file.close()
	var settings := _settings_with_controls([])
	assert_eq(settings.get_key_binding(&"interact"), KEY_E, "a fraction is no key")
	assert_eq(settings.get_key_binding(&"quick_save"), KEY_K, "nor a number past what JSON keeps exactly")
	assert_eq(settings.get_key_binding(&"quick_load"), KEY_Q, "JSON gives a whole number back as a float")

func test_duplicate_primary_key_swaps_existing_binding() -> void:
	var settings := _settings_with_controls([])
	settings.reset_controls()
	assert_eq(settings.get_key_binding(&"interact"), KEY_E)
	assert_eq(settings.get_key_binding(&"quick_save"), KEY_K)
	assert_true(settings.set_key_binding(&"interact", KEY_K))
	assert_eq(settings.get_key_binding(&"interact"), KEY_K)
	assert_eq(settings.get_key_binding(&"quick_save"), KEY_E)

func test_a_key_another_control_holds_fixed_cannot_be_bound() -> void:
	var climb := _control(&"fixture_climb", "Climb", KEY_R)
	climb.secondary_key = KEY_PAGEUP
	var pause := _control(&"fixture_pause", "Pause", KEY_P)
	pause.rebindable = false
	var settings := _settings_with_controls([climb, pause])
	settings.reset_controls()
	assert_false(settings.set_key_binding(&"interact", KEY_PAGEUP), "page up stays with climbing")
	assert_false(settings.set_key_binding(&"interact", KEY_UP), "and the up arrow with the core's move up")
	assert_false(settings.set_key_binding(&"interact", KEY_P), "a control the player cannot rebind keeps its key")
	assert_eq(settings.get_key_binding(&"interact"), KEY_E)
	assert_true(settings.set_key_binding(&"fixture_climb", KEY_PAGEUP), "a control may take its own second key")

func test_keyboard_rebinding_preserves_the_other_bindings() -> void:
	var climb := _control(&"fixture_climb", "Climb", KEY_R)
	climb.secondary_key = KEY_PAGEUP
	climb.gamepad_button = JOY_BUTTON_Y
	climb.gamepad_axis = JOY_AXIS_RIGHT_Y
	climb.gamepad_axis_value = -1.0
	var settings := _settings_with_controls([climb])
	settings.reset_controls()
	var interact_button := settings.get_control(&"interact").gamepad_button
	assert_true(settings.set_key_binding(&"interact", KEY_Q))
	assert_true(settings.set_key_binding(&"fixture_climb", KEY_I))

	assert_true(_has_key_event(&"interact", KEY_Q))
	assert_false(_has_key_event(&"interact", KEY_E))
	assert_true(_has_button_event(&"interact", interact_button), "interact keeps its gamepad button")
	assert_true(_has_key_event(&"fixture_climb", KEY_I))
	assert_true(_has_key_event(&"fixture_climb", KEY_PAGEUP), "the second key stays")
	assert_true(_has_button_event(&"fixture_climb", JOY_BUTTON_Y))
	var motions := 0
	for event: InputEvent in InputMap.action_get_events(&"fixture_climb"):
		if event is InputEventJoypadMotion and (event as InputEventJoypadMotion).axis == JOY_AXIS_RIGHT_Y:
			motions += 1
			assert_eq((event as InputEventJoypadMotion).axis_value, -1.0)
	assert_eq(motions, 1, "the stick direction stays")

func test_input_prompts_follow_the_active_device() -> void:
	var previous_gamepad := InputPrompts.using_gamepad
	InputPrompts.using_gamepad = false
	assert_eq(InputPrompts.get_action_prompt(&"interact"), GameSettings.get_key_binding_text(&"interact"))
	InputPrompts.using_gamepad = true
	var button := GameSettings.get_control(&"interact").gamepad_button
	assert_eq(InputPrompts.get_action_prompt(&"interact"), String(InputPromptService.GAMEPAD_BUTTON_LABELS[button]))
	InputPrompts.using_gamepad = previous_gamepad

func test_the_prompts_follow_the_device_while_the_world_is_paused() -> void:
	var previous_gamepad := InputPrompts.using_gamepad
	InputPrompts.using_gamepad = false
	InputLock.lock(&"fixture_menu", true)
	var press := InputEventJoypadButton.new()
	press.button_index = JOY_BUTTON_A
	press.pressed = true
	Input.parse_input_event(press)
	await _frame_done()
	var switched := InputPrompts.using_gamepad
	var release := press.duplicate() as InputEventJoypadButton
	release.pressed = false
	Input.parse_input_event(release)
	await _frame_done()
	InputLock.unlock(&"fixture_menu")
	InputPrompts.using_gamepad = previous_gamepad
	assert_true(switched, "a menu over the paused world names the gamepad's buttons")

func test_the_move_prompt_names_each_move_key_then_the_arrows() -> void:
	var moves: Array[ControlAction] = []
	for direction: String in ["up", "left", "down", "right"]:
		moves.append(load("res://gamebase/core/input/controls/move_%s.tres" % direction) as ControlAction)
	var settings := _settings_with_controls(moves)
	var previous_gamepad := InputPrompts.using_gamepad
	InputPrompts.using_gamepad = false
	# The core's move controls keep the arrows as their fixed second keys.
	assert_eq(InputPrompts.get_move_prompt(InputPromptService.MOVE_ACTIONS, settings), "W/A/S/D / Up/Left/Down/Right")
	assert_true(settings.set_key_binding(&"move_up", KEY_UP))
	assert_eq(InputPrompts.get_move_prompt(InputPromptService.MOVE_ACTIONS, settings), "Up/A/S/D / Left/Down/Right", "an arrow bound as the key is named once")
	InputPrompts.using_gamepad = true
	assert_eq(InputPrompts.get_move_prompt(InputPromptService.MOVE_ACTIONS, settings), "Left Stick / D-Pad")
	InputPrompts.using_gamepad = previous_gamepad

func test_languages_are_the_source_and_every_registered_translation() -> void:
	var locales := GameSettings.get_supported_locales()
	assert_eq(locales[0], "en", "the source language comes first")
	assert_has(locales, "zh_CN", "the core's own catalog is Simplified Chinese")
	for loaded: String in TranslationServer.get_loaded_locales():
		assert_has(locales, loaded)
	assert_eq(GameSettings.get_locale_display_name("en"), "English")
	assert_eq(GameSettings.get_locale_display_name("zh_CN"), "简体中文")
	var settings := GameSettingsService.new()
	settings.settings_path = TEST_PATH
	add_child_autofree(settings)
	settings.set_locale("x_unshipped")
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
	for control: ControlAction in GameControls.resolve(controls):
		actions.append(control.action)
	var expected: Array[StringName] = [&"jump", &"quick_save", &"move_up", &"move_down", &"move_left", &"move_right", &"interact", &"quick_load"]
	assert_eq(actions, expected)
	assert_eq(GameControls.find_problems(controls), PackedStringArray())

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
	var problems := GameControls.find_problems(controls)
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

# Waits until a change made in this frame is written, as its frame ends.
func _frame_done() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

## A settings service of a game whose controls are `controls`, followed by
## the core's own: the service reads the game's controls from its
## `GameDefinition` once, when it is created.
func _settings_with_controls(controls: Array[ControlAction]) -> GameSettingsService:
	var fixture := GameDefinition.new()
	fixture.controls.assign(controls)
	var settings: GameSettingsService = ContentFixture.with_definition(fixture, GameSettingsService.new)
	settings.settings_path = TEST_PATH
	for control: ControlAction in controls:
		_fixture_actions.append(control.action)
	add_child_autofree(settings)
	return settings

static func _control(action: StringName, display_name: String, key: Key) -> ControlAction:
	var control := ControlAction.new()
	control.action = action
	control.display_name = display_name
	control.key = key
	return control

static func _has_key_event(action: StringName, key: Key) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey and (event as InputEventKey).physical_keycode == key:
			return true
	return false

static func _has_button_event(action: StringName, button: JoyButton) -> bool:
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventJoypadButton and (event as InputEventJoypadButton).button_index == button:
			return true
	return false
