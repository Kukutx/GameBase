extends GutTest

const TEST_PATH := "user://game_settings_test.cfg"

## Input actions the fixture controls of a test added, erased after it.
var _fixture_actions: Array[StringName] = []

func after_each() -> void:
	if FileAccess.file_exists(TEST_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_PATH))
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

func test_key_bindings_round_trip_and_apply_to_input_map() -> void:
	var source := _settings_with_controls([])
	assert_true(source.set_key_binding(&"interact", KEY_Q))
	assert_eq(source.get_key_binding(&"interact"), KEY_Q)
	assert_true(_has_key_event(&"interact", KEY_Q))

	var restored := _settings_with_controls([])
	assert_eq(restored.get_key_binding(&"interact"), KEY_Q)
	assert_eq(restored.get_key_binding_text(&"interact"), OS.get_keycode_string(KEY_Q))

func test_duplicate_primary_key_swaps_existing_binding() -> void:
	var settings := _settings_with_controls([])
	settings.reset_controls()
	assert_eq(settings.get_key_binding(&"interact"), KEY_E)
	assert_eq(settings.get_key_binding(&"quick_save"), KEY_K)
	assert_true(settings.set_key_binding(&"interact", KEY_K))
	assert_eq(settings.get_key_binding(&"interact"), KEY_K)
	assert_eq(settings.get_key_binding(&"quick_save"), KEY_E)

func test_a_key_another_control_holds_fixed_cannot_be_bound() -> void:
	var climb := _control(&"fixture_climb", "Climb", KEY_W)
	climb.secondary_key = KEY_UP
	var pause := _control(&"fixture_pause", "Pause", KEY_P)
	pause.rebindable = false
	var settings := _settings_with_controls([climb, pause])
	settings.reset_controls()
	assert_false(settings.set_key_binding(&"interact", KEY_UP), "the up arrow stays with climbing")
	assert_false(settings.set_key_binding(&"interact", KEY_P), "a control the player cannot rebind keeps its key")
	assert_eq(settings.get_key_binding(&"interact"), KEY_E)
	assert_true(settings.set_key_binding(&"fixture_climb", KEY_UP), "a control may take its own second key")

func test_keyboard_rebinding_preserves_the_other_bindings() -> void:
	var climb := _control(&"fixture_climb", "Climb", KEY_W)
	climb.secondary_key = KEY_UP
	climb.gamepad_button = JOY_BUTTON_DPAD_UP
	climb.gamepad_axis = JOY_AXIS_LEFT_Y
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
	assert_true(_has_key_event(&"fixture_climb", KEY_UP), "the second key stays")
	assert_true(_has_button_event(&"fixture_climb", JOY_BUTTON_DPAD_UP))
	var motions := 0
	for event: InputEvent in InputMap.action_get_events(&"fixture_climb"):
		if event is InputEventJoypadMotion and (event as InputEventJoypadMotion).axis == JOY_AXIS_LEFT_Y:
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

## A settings service of a game whose controls are `controls`, followed by
## the core's own: the service reads the game's controls from its
## `GameDefinition` once, when it is created.
func _settings_with_controls(controls: Array[ControlAction]) -> GameSettingsService:
	var game_definition := GameDefinition.current()
	var fixture := GameDefinition.new()
	fixture.controls.assign(controls)
	GameDefinition._current = fixture
	var settings := GameSettingsService.new()
	GameDefinition._current = game_definition
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
