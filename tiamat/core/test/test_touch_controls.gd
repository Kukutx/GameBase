extends GutTest

## The controls of a touchscreen (`TouchControlsService`): a finger picks
## touch and names the controls by their buttons; in play the stick walks, the
## game's buttons press their actions and the corner button pauses; under a
## menu only the corner button shows, and it cancels; on the title nothing
## shows; going back, as Android's back button does, closes what is open or
## pauses play, and on the title has the scene go back a step before the game
## quits; a HUD line with a `TouchClearance` draws back from the controls that
## show; and the player's size and side of them, which the settings offer on a
## device played by touch, place them.

# A scene with a page to go back from, as a title's other page.
class PagedScene extends Node:
	var page := 1

	func go_back() -> bool:
		if page == 0:
			return false
		page = 0
		return true

var _menu: PauseMenu
var _touch_size: GameSettingsService.TouchSize
var _touch_stick_right := false
var _touch_opacity := 1.0

func before_each() -> void:
	_touch_size = GameSettings.touch_size
	_touch_stick_right = GameSettings.touch_stick_right
	_touch_opacity = GameSettings.touch_opacity
	InputPrompts.call("_set_using_touch", false)
	TouchControls._process(0.0)

func after_each() -> void:
	GameSettings.touch_size = _touch_size
	GameSettings.touch_stick_right = _touch_stick_right
	GameSettings.touch_opacity = _touch_opacity
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
	var view := get_viewport().get_visible_rect()
	assert_true(view.encloses(TouchControls.safe_rect()), "the clear part of the screen lies in the view")
	for control: Control in [TouchControls.get_stick(), TouchControls.get_node("Back"), TouchControls.get_node("Button_interact")]:
		assert_true(view.encloses(control.get_rect()), "%s lies in the view" % control.name)
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

func test_a_finger_on_a_button_that_goes_lets_go_and_lifts_on_nothing() -> void:
	_play()
	_use_touch()
	var button := TouchControls.get_node("Button_interact") as TouchButton
	var at := button.get_center()
	TouchControls._input(_touch(4, at, true))
	Input.flush_buffered_events()
	assert_true(Input.is_action_pressed(&"interact"))
	TouchControls.go_back()
	Input.flush_buffered_events()
	TouchControls._process(0.0)
	Input.flush_buffered_events()
	assert_false(Input.is_action_pressed(&"interact"), "the button lets go as the menu takes it away")
	assert_false(is_instance_valid(button), "and is gone at once")
	await get_tree().process_frame
	var drag := InputEventScreenDrag.new()
	drag.index = 4
	drag.position = at + Vector2(2, 0)
	TouchControls._input(drag)
	TouchControls._input(_touch(4, at, false))
	Input.flush_buffered_events()
	assert_false(Input.is_action_pressed(&"interact"), "the finger still down moves and lifts on nothing")
	assert_true(_menu.visible, "and touches nothing")

func test_a_finger_on_the_stick_as_it_hides_lets_go_and_moves_nothing() -> void:
	_play()
	_use_touch()
	var stick := TouchControls.get_stick()
	var center := stick.get_center()
	TouchControls._input(_touch(0, center, true))
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = center + Vector2(stick.radius, 0)
	TouchControls._input(drag)
	Input.flush_buffered_events()
	assert_true(Input.is_action_pressed(&"move_right"))
	TouchControls.go_back()
	Input.flush_buffered_events()
	TouchControls._process(0.0)
	assert_false(stick.visible)
	assert_false(Input.is_action_pressed(&"move_right"), "the stick lets go as the menu takes it away")
	assert_false((TouchControls.get("_fingers") as Dictionary).has(0), "the finger is the menu's now")
	TouchControls._input(drag)
	Input.flush_buffered_events()
	assert_false(Input.is_action_pressed(&"move_right"), "and moving it walks nothing")

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

func test_on_the_title_going_back_takes_the_scene_s_step_before_quitting() -> void:
	assert_eq(TouchControls.back_action(), &"", "nothing to close or pause")
	var title := GameTitleBase.new()
	assert_false(title.go_back(), "a title of one page has no step to go back")
	title.free()
	var scene := PagedScene.new()
	get_tree().root.add_child(scene)
	var before := get_tree().current_scene
	get_tree().current_scene = scene
	var stepped := TouchControls.back_step()
	var again := TouchControls.back_step()
	get_tree().current_scene = before
	assert_true(stepped, "the scene goes back a step")
	assert_eq(scene.page, 0)
	assert_false(again, "and then going back quits")
	scene.free()

func test_a_hud_line_draws_back_from_the_controls_that_show() -> void:
	_play()
	var view := get_viewport().get_visible_rect()
	var hud := CanvasLayer.new()
	add_child_autofree(hud)
	var line := Label.new()
	line.clip_text = true
	hud.add_child(line)
	var clearance := TouchClearance.new()
	line.add_child(clearance)
	_use_touch()
	var stick := TouchControls.get_stick().get_rect()
	line.position = Vector2(0.0, stick.get_center().y - 8.0)
	line.size = Vector2(view.size.x, 16.0)
	TouchControls._layout()
	assert_true(TouchControls.get_covered_rects().any(func(covered: Rect2) -> bool: return covered.position.is_equal_approx(stick.position) and covered.size.distance_to(stick.size) < 0.01), "the stick covers its square")
	var rect := line.get_global_rect()
	assert_almost_eq(rect.position.x, stick.end.x, 0.5, "the line's left side draws back from the stick")
	assert_lt(rect.end.x, view.end.x, "and its right side from the buttons")
	for covered: Rect2 in TouchControls.get_covered_rects():
		assert_false(covered.intersects(rect.grow(-0.5)), "no control sits on the line")
	assert_almost_eq(clearance.get_drawn_back().x, stick.end.x, 0.5)
	InputPrompts.call("_set_using_touch", false)
	TouchControls._process(0.0)
	assert_eq(TouchControls.get_covered_rects(), [] as Array[Rect2])
	assert_eq([line.position.x, line.size.x], [0.0, view.size.x], "the line goes back when they hide")
	assert_eq(clearance.get_drawn_back(), Vector2.ZERO)

func test_the_player_s_size_and_side_place_the_controls() -> void:
	_play()
	_use_touch()
	var view := get_viewport().get_visible_rect()
	var stick := TouchControls.get_stick()
	var button := TouchControls.get_node("Button_interact") as TouchButton
	var corner := TouchControls.get_node("Back") as TouchButton
	var normal := stick.radius
	assert_lt(stick.get_center().x, view.get_center().x, "the stick at the left")
	assert_gt(button.get_center().x, view.get_center().x, "the buttons at the right")
	GameSettings.touch_size = GameSettingsService.TouchSize.LARGE
	GameSettings.touch_stick_right = true
	TouchControls._layout()
	assert_gt(stick.radius, normal, "a larger size draws them larger")
	assert_gt(stick.get_center().x, view.get_center().x, "the stick at the right")
	assert_lt(button.get_center().x, view.get_center().x, "the buttons at the left")
	assert_gt(corner.get_center().x, view.get_center().x, "the pause button above the stick")
	for control: Control in [stick, button, corner]:
		assert_true(view.encloses(control.get_rect()), "%s lies in the view" % control.name)

func test_the_player_s_opacity_draws_every_control_fainter() -> void:
	_play()
	_use_touch()
	var controls: Array[Control] = [TouchControls.get_stick(), TouchControls.get_node("Button_interact"), TouchControls.get_node("Back")]
	for control: Control in controls:
		assert_eq(control.modulate.a, GameSettings.touch_opacity, "%s as the settings say" % control.name)
	GameSettings.touch_opacity = 0.5
	TouchControls._layout()
	for control: Control in controls:
		assert_almost_eq(control.modulate.a, 0.5, 0.001, "%s fainter" % control.name)

func test_the_settings_offer_the_touch_controls_on_a_device_played_by_touch() -> void:
	var menu := (load("res://tiamat/core/ui/settings_menu.tscn") as PackedScene).instantiate() as SettingsMenu
	add_child_autofree(menu)
	menu.open()
	assert_eq(menu.touch_size_row.visible, TouchControlsService.is_offered())
	InputPrompts.call("_set_using_touch", true)
	GameSettings.touch_size = GameSettingsService.TouchSize.SMALL
	menu.open()
	assert_true(menu.touch_size_row.visible, "a finger on the screen offers them")
	assert_true(menu.touch_stick_right_check.visible)
	assert_true(menu.touch_opacity_row.visible)
	menu.show_page(SettingsMenu.Page.CONTROLS)
	assert_eq(get_viewport().gui_get_focus_owner(), menu.touch_size_select, "the page opens at its top, on the touch controls")
	assert_eq(menu.touch_size_select.selected, GameSettingsService.TouchSize.SMALL)
	GameSettings.touch_opacity = 0.6
	menu.open()
	assert_almost_eq(menu.touch_opacity_slider.value, 60.0, 0.001)
	menu.touch_opacity_slider.value = 40.0
	assert_almost_eq(GameSettings.touch_opacity, 0.4, 0.001, "the slider sets it")

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
