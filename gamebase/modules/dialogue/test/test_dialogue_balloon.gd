extends GutTest

## The box a conversation shows in (`DialogueBalloon`): it types a line out at
## the player's text speed, shows the rest of it and then the next line at a
## press or a click, offers the responses and takes one pick of them, fits the
## game's view and frees itself at the end.

const MenuFit := preload("res://gamebase/core/test/menu_fit.gd")
const DIALOGUE_TEXT := """~ start
Fixture: Good morning, it is a fine day to walk along the river.
Fixture: Will you help me?
- Yes
	Fixture: Thank you!
- No
	Fixture: Maybe tomorrow.
=> END

~ long
Fixture: %s
=> END

~ choose
Fixture: Pick one.
- Slow
	do wait(0.2)
	Fixture: That took a while.
- Quick
	Fixture: Quick it is.
=> END
"""

var _text_speed: GameSettingsService.TextSpeed

func before_each() -> void:
	_text_speed = GameSettings.text_speed

func after_each() -> void:
	GameSettings.text_speed = _text_speed
	InputLock.unlock(DialogueService.LOCK)

func test_a_line_types_out_at_the_text_speed_and_a_press_shows_the_rest_then_the_next() -> void:
	GameSettings.text_speed = GameSettingsService.TextSpeed.SLOW
	var balloon := await _start("start")
	var first := balloon.get_line()
	assert_eq(first.text, "Good morning, it is a fine day to walk along the river.")
	assert_true(balloon.is_typing(), "a slow line is still typing")
	balloon.advance()
	assert_false(balloon.is_typing(), "a press shows the rest of the line")
	assert_same(balloon.get_line(), first)
	await wait_process_frames(1)
	balloon.advance()
	await wait_until(func() -> bool: return balloon.get_line() != first, 1.0)
	assert_eq(balloon.get_line().text, "Will you help me?", "the next press shows the next line")

func test_instant_text_shows_a_line_at_once_and_waits_for_a_press() -> void:
	GameSettings.text_speed = GameSettingsService.TextSpeed.INSTANT
	var balloon := await _start("start")
	await wait_until(func() -> bool: return balloon.get_node("%More").visible, 1.0)
	assert_false(balloon.is_typing())
	assert_true(balloon.get_node("%More").visible, "the cue to go on")

func test_the_chosen_response_leads_on_and_the_end_frees_the_balloon() -> void:
	GameSettings.text_speed = GameSettingsService.TextSpeed.INSTANT
	var balloon := await _start("start")
	# Shown in full, so the press moves on rather than ends the typing.
	await wait_until(func() -> bool: return balloon.get_node("%More").visible, 1.0)
	balloon.advance()
	await wait_until(func() -> bool: return balloon.get_node("%Responses").visible, 1.0)
	var line := balloon.get_line()
	assert_eq(line.responses.size(), 2)
	var responses := balloon.get_node("%Responses") as DialogueResponsesMenu
	assert_eq(responses.get_menu_items().size(), 2, "a button for each response")
	responses.response_selected.emit(line.responses[1])
	await wait_until(func() -> bool: return balloon.get_line() != line, 1.0)
	assert_eq(balloon.get_line().text, "Maybe tomorrow.")
	await wait_process_frames(1)
	var gone := [false]
	balloon.tree_exited.connect(func() -> void: gone[0] = true)
	balloon.advance()
	await wait_until(func() -> bool: return gone[0], 1.0)
	assert_true(gone[0], "the end of the dialogue frees it")

func test_a_press_moves_on_only_while_the_conversation_s_lock_is_on_top() -> void:
	GameSettings.text_speed = GameSettingsService.TextSpeed.INSTANT
	var balloon := await _start("start")
	await wait_until(func() -> bool: return balloon.get_node("%More").visible, 1.0)
	var first := balloon.get_line()
	var press := InputEventAction.new()
	press.action = &"ui_accept"
	press.pressed = true
	balloon._unhandled_input(press)
	await wait_process_frames(2)
	assert_same(balloon.get_line(), first, "without the lock the balloon does not read keys")
	InputLock.lock(DialogueService.LOCK, false, balloon)
	balloon._unhandled_input(press)
	await wait_until(func() -> bool: return balloon.get_line() != first, 1.0)
	assert_eq(balloon.get_line().text, "Will you help me?")

func test_a_click_on_the_panel_moves_on() -> void:
	GameSettings.text_speed = GameSettingsService.TextSpeed.INSTANT
	var balloon := await _start("start")
	await wait_until(func() -> bool: return balloon.get_node("%More").visible, 1.0)
	InputLock.lock(DialogueService.LOCK, false, balloon)
	var first := balloon.get_line()
	var panel := balloon.get_node("%Panel") as Control
	assert_eq(panel.mouse_filter, Control.MOUSE_FILTER_STOP, "a click on the box does not reach the world")
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	# The click as the panel receives it: GUT's own panel would take one pushed
	# through the viewport.
	panel.gui_input.emit(click)
	await wait_until(func() -> bool: return balloon.get_line() != first, 1.0)
	assert_eq(balloon.get_line().text, "Will you help me?")

func test_a_response_is_picked_once_even_while_its_branch_waits() -> void:
	GameSettings.text_speed = GameSettingsService.TextSpeed.INSTANT
	var balloon := await _start("choose")
	await wait_until(func() -> bool: return balloon.get_node("%Responses").visible, 1.0)
	var line := balloon.get_line()
	var responses := balloon.get_node("%Responses") as DialogueResponsesMenu
	responses.response_selected.emit(line.responses[0])
	assert_false(responses.visible, "the responses hide once one is picked")
	responses.response_selected.emit(line.responses[1])
	await wait_until(func() -> bool: return balloon.get_line() != line, 1.0)
	assert_eq(balloon.get_line().text, "That took a while.", "the second pick, made while the first branch waited, is ignored")

func test_interact_picks_the_response_in_focus() -> void:
	GameSettings.text_speed = GameSettingsService.TextSpeed.INSTANT
	var balloon := await _start("start")
	# Shown in full, so the press moves on rather than ends the typing.
	await wait_until(func() -> bool: return balloon.get_node("%More").visible, 1.0)
	balloon.advance()
	await wait_until(func() -> bool: return balloon.get_node("%Responses").visible, 1.0)
	InputLock.lock(DialogueService.LOCK, false, balloon)
	var line := balloon.get_line()
	((balloon.get_node("%Responses") as DialogueResponsesMenu).get_menu_items()[1] as Control).grab_focus()
	var press := InputEventAction.new()
	press.action = &"interact"
	press.pressed = true
	balloon._unhandled_input(press)
	await wait_until(func() -> bool: return balloon.get_line() != line, 1.0)
	assert_eq(balloon.get_line().text, "Maybe tomorrow.")

func test_the_balloon_fits_the_view_and_grows_upwards_for_a_long_line() -> void:
	GameSettings.text_speed = GameSettingsService.TextSpeed.INSTANT
	var view := get_viewport().get_visible_rect()
	var balloon := await _start("start")
	await wait_process_frames(2)
	var panel := balloon.get_node("%Panel") as Control
	var short_height := panel.size.y
	assert_eq(MenuFit.find_overflow(balloon, view), PackedStringArray())
	assert_almost_eq(panel.get_global_rect().end.y, view.end.y - 6.0, 0.5, "along the bottom")
	balloon.queue_free()

	var long := await _start("long", "The river runs past the mill. ".repeat(8).strip_edges())
	await wait_process_frames(2)
	var long_panel := long.get_node("%Panel") as Control
	assert_gt(long_panel.size.y, short_height, "a long line makes the panel taller")
	assert_eq(MenuFit.find_overflow(long, view), PackedStringArray())

func test_a_dialogue_that_ran_is_freed_once_nothing_holds_it() -> void:
	var resource := DialogueManager.create_resource_from_text(DIALOGUE_TEXT % "") as DialogueResource
	var line: DialogueLine = await resource.get_next_dialogue_line("start")
	assert_not_null(line)
	var held: WeakRef = weakref(resource)
	resource = null
	line = null
	# The addon hands each line over on the next frame.
	await wait_process_frames(1)
	assert_null(held.get_ref(), "its lines do not hold it (the GameBase fix in the addon's get_line)")

# A balloon showing the fixture dialogue from `cue`, once its first line shows.
func _start(cue: String, long_line := "") -> DialogueBalloon:
	var resource := DialogueManager.create_resource_from_text(DIALOGUE_TEXT % long_line) as DialogueResource
	var balloon := DialogueService.BALLOON_SCENE.instantiate() as DialogueBalloon
	add_child_autofree(balloon)
	balloon.start(resource, cue, [])
	await wait_until(func() -> bool: return balloon.get_line() != null, 1.0)
	return balloon
