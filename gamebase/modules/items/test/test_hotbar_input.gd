extends GutTest

## Picking the hotbar's slot from the player's input (`HotbarInput`).

var _selected := 0

func before_each() -> void:
	_selected = Hotbar.selected_slot
	Hotbar.select_slot(0)

func after_each() -> void:
	Hotbar.select_slot(_selected)

func test_number_keys_and_the_wheel_pick_slots() -> void:
	var input := _hotbar_input()
	input._unhandled_input(_key(KEY_3))
	assert_eq(Hotbar.selected_slot, 2)
	input._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN))
	assert_eq(Hotbar.selected_slot, 3)
	input._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	assert_eq(Hotbar.selected_slot, 2)
	input.number_keys = false
	input._unhandled_input(_key(KEY_1))
	assert_eq(Hotbar.selected_slot, 2, "number keys can be left to the game")

func test_an_action_the_game_has_not_is_no_error_and_nothing_moves_while_locked() -> void:
	var input := _hotbar_input()
	input.next_action = &"fixture_action_no_game_has"
	input._unhandled_input(_key(KEY_A))
	assert_eq(Hotbar.selected_slot, 0)
	InputLock.lock(&"test_hotbar_input")
	input._unhandled_input(_key(KEY_2))
	InputLock.unlock(&"test_hotbar_input")
	assert_eq(Hotbar.selected_slot, 0, "nothing moves while the controls are held")

func test_the_next_and_previous_actions_step_through_the_slots() -> void:
	_add_action(&"fixture_hotbar_next", KEY_PERIOD)
	_add_action(&"fixture_hotbar_previous", KEY_COMMA)
	var input := _hotbar_input()
	input.next_action = &"fixture_hotbar_next"
	input.previous_action = &"fixture_hotbar_previous"
	input._unhandled_input(_key(KEY_PERIOD))
	input._unhandled_input(_key(KEY_PERIOD))
	assert_eq(Hotbar.selected_slot, 2)
	input._unhandled_input(_key(KEY_COMMA))
	assert_eq(Hotbar.selected_slot, 1)

func test_a_number_key_bound_to_a_control_stays_with_it() -> void:
	_add_action(&"fixture_drink", KEY_2)
	_add_action(&"fixture_hotbar_next", KEY_3)
	var input := _hotbar_input()
	input.next_action = &"fixture_hotbar_next"
	input._unhandled_input(_key(KEY_2))
	assert_eq(Hotbar.selected_slot, 0, "the key drinks rather than picking slot 2")
	input._unhandled_input(_key(KEY_3))
	assert_eq(Hotbar.selected_slot, 1, "a number key bound to the next action steps")
	input._unhandled_input(_key(KEY_5))
	assert_eq(Hotbar.selected_slot, 4, "the other number keys still pick their slot")

func test_a_wheel_turn_bound_to_a_control_stays_with_it() -> void:
	InputMap.add_action(&"fixture_zoom")
	InputMap.action_add_event(&"fixture_zoom", _wheel(MOUSE_BUTTON_WHEEL_UP))
	var holder := Node.new()
	add_child_autofree(holder)
	holder.tree_exiting.connect(func() -> void: InputMap.erase_action(&"fixture_zoom"))
	var input := _hotbar_input()
	input._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN))
	assert_eq(Hotbar.selected_slot, 1)
	input._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	assert_eq(Hotbar.selected_slot, 1, "the wheel up zooms rather than stepping back")

func test_nothing_moves_while_the_player_acts() -> void:
	var player := TopDownPlayer.new()
	var visual := DirectionalActorVisual.new()
	player.actor_visual = visual
	player.add_child(visual)
	var input := HotbarInput.new()
	player.add_child(input)
	add_child_autofree(player)
	visual._action_playing = true
	input._unhandled_input(_key(KEY_4))
	assert_eq(Hotbar.selected_slot, 0, "the player's own action holds the hotbar")
	visual._action_playing = false
	input._unhandled_input(_key(KEY_4))
	assert_eq(Hotbar.selected_slot, 3)

func _hotbar_input() -> HotbarInput:
	var input := HotbarInput.new()
	add_child_autofree(input)
	return input

# An action of the game with `key`, until the test ends.
func _add_action(action: StringName, key: Key) -> void:
	InputMap.add_action(action)
	var event := InputEventKey.new()
	event.physical_keycode = key
	InputMap.action_add_event(action, event)
	var holder := Node.new()
	add_child_autofree(holder)
	holder.tree_exiting.connect(func() -> void: InputMap.erase_action(action))

func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	event.physical_keycode = keycode
	event.pressed = true
	return event

func _wheel(button: MouseButton) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	return event
