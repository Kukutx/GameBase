extends GutTest

## The names prompts give a gamepad's buttons (`InputPromptService`): as its
## maker prints them, told from the pad's name, in characters the game's font
## draws; and the gamepad in use leaving takes the prompts back to the
## keyboard.

var _using_gamepad := false
var _style := InputPromptService.GamepadStyle.XBOX

func before_each() -> void:
	_using_gamepad = InputPrompts.using_gamepad
	_style = InputPrompts.gamepad_style

func after_each() -> void:
	InputPrompts.using_gamepad = _using_gamepad
	InputPrompts.gamepad_style = _style
	InputPrompts.set("_gamepad_device", -1)

func test_a_pads_name_tells_its_style() -> void:
	assert_eq(InputPromptService.style_of("Xbox Series Controller"), InputPromptService.GamepadStyle.XBOX)
	assert_eq(InputPromptService.style_of("PS5 Controller"), InputPromptService.GamepadStyle.PLAYSTATION)
	assert_eq(InputPromptService.style_of("Sony DualSense Wireless Controller"), InputPromptService.GamepadStyle.PLAYSTATION)
	assert_eq(InputPromptService.style_of("Nintendo Switch Pro Controller"), InputPromptService.GamepadStyle.NINTENDO)
	assert_eq(InputPromptService.style_of("Joy-Con (L/R)"), InputPromptService.GamepadStyle.NINTENDO)
	assert_eq(InputPromptService.style_of(""), InputPromptService.GamepadStyle.XBOX, "a pad of no known maker reads as an Xbox pad")

func test_the_buttons_are_named_as_the_pad_in_use_prints_them() -> void:
	InputPrompts.using_gamepad = true
	var interact := GameSettings.bindings.get_gamepad_button(&"interact")
	assert_eq(interact, JOY_BUTTON_A)
	InputPrompts.call("_set_gamepad_style", InputPromptService.GamepadStyle.XBOX)
	assert_eq(InputPrompts.get_action_prompt(&"interact"), "A")
	assert_eq(InputPrompts.get_action_prompt(&"pause"), "Start")
	watch_signals(InputPrompts)
	InputPrompts.call("_set_gamepad_style", InputPromptService.GamepadStyle.PLAYSTATION)
	assert_signal_emitted(InputPrompts, "input_method_changed", "prompts on screen show the new names")
	assert_eq(InputPrompts.get_action_prompt(&"interact"), "×")
	assert_eq(InputPrompts.get_action_prompt(&"pause"), "Options")
	assert_eq(InputPromptService.gamepad_axis_name(JOY_AXIS_TRIGGER_LEFT, InputPromptService.GamepadStyle.PLAYSTATION), "L2")
	InputPrompts.call("_set_gamepad_style", InputPromptService.GamepadStyle.NINTENDO)
	assert_eq(InputPrompts.get_action_prompt(&"interact"), "B", "the bottom button")
	assert_eq(InputPromptService.gamepad_axis_name(JOY_AXIS_TRIGGER_RIGHT, InputPromptService.GamepadStyle.NINTENDO), "ZR")
	assert_eq(InputPromptService.gamepad_button_name(JOY_BUTTON_DPAD_UP, InputPromptService.GamepadStyle.NINTENDO), "D-Pad ↑", "a button every pad names alike")

func test_the_games_font_draws_every_buttons_name() -> void:
	var label := Label.new()
	add_child_autofree(label)
	var font := label.get_theme_font(&"font")
	for style: int in InputPromptService.GamepadStyle.values():
		for button: int in range(JOY_BUTTON_SDL_MAX):
			var label_text := InputPromptService.gamepad_button_name(button as JoyButton, style as InputPromptService.GamepadStyle)
			for index: int in label_text.length():
				var code := label_text.unicode_at(index)
				assert_true(code <= 0x20 or font.has_char(code), "%s of %s" % [label_text[index], label_text])

func test_the_pad_in_use_leaving_takes_the_prompts_to_the_keyboard() -> void:
	InputPrompts.call("_use_gamepad", 7)
	assert_true(InputPrompts.using_gamepad)
	watch_signals(InputPrompts)
	Input.joy_connection_changed.emit(3, false)
	assert_true(InputPrompts.using_gamepad, "another pad leaving changes nothing")
	assert_signal_not_emitted(InputPrompts, "gamepad_disconnected")
	Input.joy_connection_changed.emit(7, false)
	assert_false(InputPrompts.using_gamepad)
	assert_signal_emitted(InputPrompts, "gamepad_disconnected")
