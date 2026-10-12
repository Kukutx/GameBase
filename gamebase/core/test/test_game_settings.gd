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

func test_bindings_round_trip_and_apply_to_input_map() -> void:
	var source := _settings_with_controls([])
	assert_true(source.bind_control(&"interact", {"key": int(KEY_Q)}))
	assert_true(source.bind_control(&"quick_save", {"mouse": int(MOUSE_BUTTON_MIDDLE)}))
	assert_eq(source.bindings.get_binding(&"interact"), {"key": int(KEY_Q)})
	assert_true(_has_key_event(&"interact", KEY_Q))
	assert_false(_has_key_event(&"quick_save", KEY_K), "the mouse button takes the key's place")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_MIDDLE
	click.pressed = true
	assert_true(click.is_action_pressed(&"quick_save"))
	await _frame_done()

	var restored := _settings_with_controls([])
	assert_eq(restored.bindings.get_binding(&"interact"), {"key": int(KEY_Q)})
	assert_eq(restored.bindings.get_binding_text(&"interact"), OS.get_keycode_string(KEY_Q))
	assert_eq(restored.bindings.get_binding(&"quick_save"), {"mouse": int(MOUSE_BUTTON_MIDDLE)})
	assert_eq(restored.bindings.get_binding_text(&"quick_save"), "Mouse Middle")

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
		press.button_index = settings.bindings.get_gamepad_button(&"interact")
		press.pressed = true
		assert_true(press.is_action_pressed(&"interact"), "gamepad %d interacts" % device)

func test_a_binding_that_is_not_a_whole_key_or_button_reads_as_the_default() -> void:
	assert_eq(JsonFile.write(TEST_PATH, {"settings_version": GameSettingsService.SETTINGS_VERSION, "controls": {
		"interact": {"key": 81.5},
		"quick_save": {"key": 1e19},
		"quick_load": {"key": 81.0},
		"move_up": {"key": 73, "mouse": 3},
		"move_down": {"mouse": "middle"},
		"move_left": 74,
	}}), "")
	var settings := _settings_with_controls([])
	var bindings := settings.bindings
	assert_eq(bindings.get_binding(&"interact"), {"key": int(KEY_E)}, "a fraction is no key")
	assert_eq(bindings.get_binding(&"quick_save"), {"key": int(KEY_K)}, "nor a number past what JSON keeps exactly")
	assert_eq(bindings.get_binding(&"quick_load"), {"key": int(KEY_Q)}, "JSON gives a whole number back as a float")
	assert_eq(bindings.get_binding(&"move_up"), {"key": int(KEY_W)}, "a key and a button at once are neither")
	assert_eq(bindings.get_binding(&"move_down"), {"key": int(KEY_S)})
	assert_eq(bindings.get_binding(&"move_left"), {"key": int(KEY_A)}, "a bare number is no binding")

func test_bindings_two_controls_would_share_read_as_the_defaults() -> void:
	assert_eq(JsonFile.write(TEST_PATH, {"settings_version": GameSettingsService.SETTINGS_VERSION, "controls": {
		"interact": {"key": int(KEY_K)},
		"quick_load": {"key": int(KEY_J)},
	}}), "")
	var settings := _settings_with_controls([])
	assert_eq(settings.bindings.get_binding(&"interact"), {"key": int(KEY_E)}, "quick save keeps K, so the file's bindings clash")
	assert_eq(settings.bindings.get_binding(&"quick_load"), {"key": int(KEY_L)})

func test_duplicate_primary_key_swaps_existing_binding() -> void:
	var settings := _settings_with_controls([])
	settings.reset_controls()
	assert_true(settings.bind_control(&"interact", {"key": int(KEY_K)}))
	assert_eq(settings.bindings.get_binding(&"interact"), {"key": int(KEY_K)})
	assert_eq(settings.bindings.get_binding(&"quick_save"), {"key": int(KEY_E)})
	assert_true(settings.bind_control(&"quick_load", {"mouse": int(MOUSE_BUTTON_RIGHT)}))
	assert_true(settings.bind_control(&"interact", {"mouse": int(MOUSE_BUTTON_RIGHT)}), "a mouse button swaps too")
	assert_eq(settings.bindings.get_binding(&"quick_load"), {"key": int(KEY_K)})

func test_a_key_another_control_holds_fixed_cannot_be_bound() -> void:
	var climb := _control(&"fixture_climb", "Climb", KEY_R)
	climb.secondary_key = KEY_PAGEUP
	var pause := _control(&"fixture_pause", "Pause", KEY_P)
	pause.rebindable = false
	var look := _control(&"fixture_look", "Look", KEY_NONE)
	look.mouse_button = MOUSE_BUTTON_RIGHT
	look.rebindable = false
	var settings := _settings_with_controls([climb, pause, look])
	settings.reset_controls()
	assert_false(settings.bind_control(&"interact", {"key": int(KEY_PAGEUP)}), "page up stays with climbing")
	assert_false(settings.bind_control(&"interact", {"key": int(KEY_UP)}), "and the up arrow with the core's move up")
	assert_false(settings.bind_control(&"interact", {"key": int(KEY_P)}), "a control the player cannot rebind keeps its key")
	assert_false(settings.bind_control(&"interact", {"mouse": int(MOUSE_BUTTON_RIGHT)}), "and its mouse button")
	assert_eq(settings.bindings.get_binding(&"interact"), {"key": int(KEY_E)})
	assert_true(settings.bind_control(&"fixture_climb", {"key": int(KEY_PAGEUP)}), "a control may take its own second key")
	assert_false(settings.bind_control(&"fixture_climb", {"key": int(KEY_E)}), "but cannot hand it to interact in a swap")
	assert_eq(settings.bindings.get_binding(&"interact"), {"key": int(KEY_E)})
	assert_eq(settings.bindings.get_binding(&"fixture_climb"), {"key": int(KEY_PAGEUP)})

func test_the_controls_of_a_group_share_bindings_only_among_themselves() -> void:
	var charge := _control(&"fixture_charge", "Charge", KEY_A)
	charge.group = "Fixture Battle"
	charge.gamepad_button = JOY_BUTTON_A
	var retreat := _control(&"fixture_retreat", "Retreat", KEY_R)
	retreat.group = "Fixture Battle"
	retreat.secondary_key = KEY_BACKSPACE
	var settings := _settings_with_controls([charge, retreat])
	settings.reset_controls()
	assert_eq(GameControls.find_problems([charge, retreat], []), PackedStringArray(), "the battle's A and gamepad A are the world's too")
	assert_true(settings.bind_control(&"fixture_charge", {"key": int(KEY_UP)}), "the world's arrow is not the battle's")
	assert_eq(settings.bindings.get_binding(&"move_up"), {"key": int(KEY_W)})
	assert_true(settings.bind_control(&"fixture_charge", {"key": int(KEY_E)}), "nor is the world's interact key")
	assert_eq(settings.bindings.get_binding(&"interact"), {"key": int(KEY_E)}, "a binding of another group stays")
	assert_true(settings.bind_control(&"interact", {"key": int(KEY_BACKSPACE)}), "a second key of another group holds nothing here")
	assert_true(settings.bind_control(&"fixture_retreat", {"key": int(KEY_E)}), "within the group the two swap")
	assert_eq(settings.bindings.get_binding(&"fixture_charge"), {"key": int(KEY_R)})
	assert_true(settings.bind_gamepad_button(&"interact", JOY_BUTTON_X))
	assert_eq(settings.bindings.get_gamepad_button(&"fixture_charge"), JOY_BUTTON_A, "a gamepad button is shared across groups as well")

func test_keyboard_rebinding_preserves_the_other_bindings() -> void:
	var climb := _control(&"fixture_climb", "Climb", KEY_R)
	climb.secondary_key = KEY_PAGEUP
	climb.gamepad_button = JOY_BUTTON_Y
	climb.gamepad_axis = JOY_AXIS_RIGHT_Y
	climb.gamepad_axis_value = -1.0
	var settings := _settings_with_controls([climb])
	settings.reset_controls()
	var interact_button := settings.bindings.get_control(&"interact").gamepad_button
	assert_true(settings.bind_control(&"interact", {"key": int(KEY_Q)}))
	assert_true(settings.bind_control(&"fixture_climb", {"key": int(KEY_I)}))

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
	assert_eq(InputPrompts.get_action_prompt(&"interact"), GameSettings.bindings.get_binding_text(&"interact"))
	InputPrompts.using_gamepad = true
	var button := GameSettings.bindings.get_control(&"interact").gamepad_button
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
	assert_eq(InputPrompts.get_move_prompt(InputPromptService.MOVE_ACTIONS, settings.bindings), "W/A/S/D / Up/Left/Down/Right")
	assert_true(settings.bind_control(&"move_up", {"key": int(KEY_UP)}))
	assert_eq(InputPrompts.get_move_prompt(InputPromptService.MOVE_ACTIONS, settings.bindings), "Up/A/S/D / Left/Down/Right", "an arrow bound as the key is named once")
	assert_true(settings.bind_control(&"move_down", {"mouse": int(MOUSE_BUTTON_WHEEL_DOWN)}))
	assert_eq(InputPrompts.get_move_prompt(InputPromptService.MOVE_ACTIONS, settings.bindings), "Up/A/Wheel Down/D / Left/Down/Right")
	InputPrompts.using_gamepad = true
	assert_eq(InputPrompts.get_move_prompt(InputPromptService.MOVE_ACTIONS, settings.bindings), "Left Stick / D-Pad")
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

func test_the_modules_controls_come_between_the_games_and_the_cores_and_the_game_replaces_any() -> void:
	var jump := _control(&"jump", "Jump", KEY_SPACE)
	var save := _control(&"quick_save", "Save", KEY_F5)
	var game_cast := _control(&"cast", "Cast", KEY_C)
	var module_cast := _control(&"cast", "Cast a Line", KEY_V)
	var reel := _control(&"reel", "Reel", KEY_B)
	var controls: Array[ControlAction] = [jump, save, game_cast]
	var module_controls: Array[ControlAction] = [module_cast, reel]
	var resolved := GameControls.resolve(controls, module_controls)
	var actions: Array[StringName] = []
	for control: ControlAction in resolved:
		actions.append(control.action)
	var expected: Array[StringName] = [&"jump", &"quick_save", &"cast", &"reel", &"move_up", &"move_down", &"move_left", &"move_right", &"interact", &"quick_load"]
	assert_eq(actions, expected)
	assert_true(resolved.has(game_cast) and not resolved.has(module_cast), "the game's control of an action replaces the module's")
	assert_eq(GameControls.find_problems(controls, module_controls), PackedStringArray())

func test_the_running_games_controls_take_in_its_modules() -> void:
	var expected := GameControls.of_modules()
	for control: ControlAction in expected:
		assert_has(GameSettings.bindings.get_controls().map(func(each: ControlAction) -> StringName: return each.action), control.action)
	assert_eq(GameControls.find_problems(GameControls.of_game(), expected), PackedStringArray())

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
	var both := _control(&"aim", "Aim", KEY_T)
	both.mouse_button = MOUSE_BUTTON_RIGHT
	var wheel := _control(&"zoom", "Zoom", KEY_NONE)
	wheel.mouse_button = MOUSE_BUTTON_WHEEL_UP
	var other_wheel := _control(&"scroll", "Scroll", KEY_NONE)
	other_wheel.mouse_button = MOUSE_BUTTON_WHEEL_UP
	var controls: Array[ControlAction] = [nameless, keyless, clash, unbound, clash, second, null, both, wheel]
	var module_controls: Array[ControlAction] = [other_wheel, null, other_wheel]
	var problems := GameControls.find_problems(controls, module_controls)
	for expected: String in [
		"GameDefinition.controls has an entry that is not a ControlAction",
		"a module declares a control that is not a ControlAction",
		"rebindable control 'dash' has no display name",
		"rebindable control 'block' has no default key or mouse button",
		"control 'block' has no key, mouse button, gamepad button or axis",
		"control 'emote' has no key, mouse button, gamepad button or axis",
		"control 'talk' is listed twice",
		"two modules declare control 'scroll'",
		"controls 'talk' and 'interact' share the default key E",
		"controls 'dodge' and 'quick_save' share the default key K",
		"control 'aim' has both a default key and a default mouse button",
		"controls 'zoom' and 'scroll' share the default mouse button Wheel Up",
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
