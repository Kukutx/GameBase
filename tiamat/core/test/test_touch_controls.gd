extends GutTest

## The controls of a touchscreen (`TouchControlsService`): a finger picks
## touch and names the controls by their buttons; in play the stick walks, the
## game's buttons press their actions and the corner button pauses; under a
## menu only the corner button shows, and it cancels; on the title nothing
## shows; and going back, as Android's back button does, closes what is open or
## pauses play.

var _menu: PauseMenu

func before_each() -> void:
	InputPrompts.call("_set_using_touch", false)
	TouchControls._process(0.0)

func after_each() -> void:
	InputPrompts.call("_set_using_touch", false)
	InputPrompts.call("_set_using_gamepad", false)
	InputLock.clear()
	TouchControls._process(0.0)
	for action: StringName in TouchStick.MOVE_ACTIONS + [&"interact"]:
		Input.action_release(action)
	Input.flush_buffered_events()

func test_a_finger_picks_touch_and_a_key_takes_it_back() -> void:
	watch_signals(InputPrompts)
	InputPrompts._input(_touch(0, Vector2(10, 10), true))
	assert_true(InputPrompts.using_touch)
	assert_signal_emitted(InputPrompts, "input_method_changed", "prompts on screen name the buttons")
	assert_eq(InputPrompts.get_action_prompt(&"interact"), GameSettings.bindings.get_label(&"interact"), "a control is named as its button names it")
	assert_eq(InputPrompts.get_move_prompt(), tr("Stick"))
	var tap := InputEventMouseButton.new()
	tap.device = InputEvent.DEVICE_ID_EMULATION
	tap.button_index = MOUSE_BUTTON_LEFT
	tap.pressed = true
	InputPrompts._input(tap)
	assert_true(InputPrompts.using_touch, "the click the engine makes of a finger keeps touch")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	InputPrompts._input(key)
	assert_false(InputPrompts.using_touch, "a key goes back to the keyboard")
	assert_ne(InputPrompts.get_move_prompt(), tr("Stick"))

func test_nothing_shows_without_touch_or_out_of_play() -> void:
	_play()
	TouchControls._process(0.0)
	assert_false(TouchControls.is_showing(), "a keyboard player sees no touch controls")
	remove_child(_menu)
	InputPrompts.call("_set_using_touch", true)
	TouchControls._process(0.0)
	assert_false(TouchControls.is_showing(), "the title is tapped, so nothing shows there")
	assert_eq(TouchControls.back_action(), &"", "and going back from it quits")

func test_in_play_the_stick_walks_and_the_game_s_buttons_show() -> void:
	_play()
	_use_touch()
	assert_true(TouchControls.is_showing())
	var actions := TouchControls.get_shown_actions()
	assert_true(actions.has(&"interact"), "the core's interact has a button")
	assert_false(actions.has(&"move_up"), "the moves are the stick's")
	assert_false(actions.has(&"pause"), "the pause is the corner's")
	assert_eq(actions, TouchControlsService.game_touch_actions())
	var stick := TouchControls.get_stick()
	assert_true(stick.visible, "something walks, so the stick shows")
	var center := stick.get_center()
	TouchControls._input(_touch(1, center, true))
	TouchControls._input(_drag(1, center + Vector2(stick.radius, 0)))
	var walk := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	assert_almost_eq(walk.x, 1.0, 0.01, "a finger at the ring's edge walks at full speed")
	assert_almost_eq(walk.y, 0.0, 0.01)
	TouchControls._input(_drag(1, center + Vector2(0, -stick.radius * 0.1)))
	assert_eq(Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down"), Vector2.ZERO, "inside the dead zone the player stands")
	TouchControls._input(_drag(1, center + Vector2(0, -stick.radius * 0.6)))
	assert_lt(Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down").y, 0.0)
	TouchControls._input(_touch(1, center, false))
	assert_eq(Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down"), Vector2.ZERO, "lifting the finger stops the walk")

func test_the_stick_hides_where_nothing_walks() -> void:
	_play(false)
	_use_touch()
	assert_true(TouchControls.is_showing())
	assert_false(TouchControls.get_stick().visible)

func test_a_button_holds_its_action_while_the_finger_is_on_it() -> void:
	_play()
	_use_touch()
	var button := TouchControls.get_node("Button_interact") as TouchButton
	assert_not_null(button)
	assert_eq(button.label, GameSettings.bindings.get_label(&"interact"))
	TouchControls._input(_touch(2, button.get_center(), true))
	Input.flush_buffered_events()
	assert_true(Input.is_action_pressed(&"interact"))
	TouchControls._input(_touch(2, button.get_center(), false))
	Input.flush_buffered_events()
	assert_false(Input.is_action_pressed(&"interact"))

func test_going_back_pauses_play_and_closes_what_is_open() -> void:
	_play()
	_use_touch()
	assert_eq(TouchControls.back_action(), &"pause")
	var corner := TouchControls.get_node("Back") as TouchButton
	assert_true(corner.visible)
	assert_eq(corner.sign_shown, TouchButton.Sign.PAUSE)
	TouchControls.go_back()
	Input.flush_buffered_events()
	assert_true(_menu.visible, "back in play opens the pause menu")
	TouchControls._process(0.0)
	assert_eq(TouchControls.back_action(), &"ui_cancel")
	assert_eq(TouchControls.get_shown_actions(), [] as Array[StringName], "the menu is tapped, so the game's buttons go")
	assert_false(TouchControls.get_stick().visible)
	assert_true(corner.visible, "the corner button closes the menu")
	assert_eq(corner.sign_shown, TouchButton.Sign.BACK)
	TouchControls._input(_touch(3, corner.get_center(), true))
	TouchControls._input(_touch(3, corner.get_center(), false))
	Input.flush_buffered_events()
	assert_false(_menu.visible, "and so does back")

func test_a_minigame_is_tapped_unless_it_asks_for_buttons() -> void:
	var minigame := MiniGame.new()
	assert_eq(minigame.get_touch_actions(), [] as Array[StringName])
	assert_false(minigame.uses_touch_stick())
	minigame.free()

# A scene in play: its pause menu, and a player that walks unless `walks` is
# false.
func _play(walks := true) -> void:
	_menu = (load("res://tiamat/core/ui/pause_menu.tscn") as PackedScene).instantiate() as PauseMenu
	add_child_autofree(_menu)
	if walks:
		var mover := Node.new()
		mover.add_to_group(TouchControlsService.MOVER_GROUP)
		add_child_autofree(mover)

func _use_touch() -> void:
	InputPrompts.call("_set_using_touch", true)
	TouchControls._process(0.0)

static func _touch(index: int, at: Vector2, pressed: bool) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = pressed
	return event

static func _drag(index: int, at: Vector2) -> InputEventScreenDrag:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.position = at
	return event
