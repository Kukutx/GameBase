extends GutTest

## The rts module's minigame (`RtsBattleGame`) run by `MiniGameHost`: the
## player selects their units with clicks and a box and sends them after a
## foe with a right click, wins, and the battle's end is told; the keys give
## the commands, as the player rebinds them, and keep groups; the cursor
## selects and orders with accept and
## interact, and a command key that also steers leaves it be; holding the
## ground is told and wins; a finger
## selects and orders with taps, and the command buttons name only their
## command; cancel drops an
## armed attack-move, then the selection, and twice gives the battle up; an
## unknown map ends it at once, and a definition that names one is a content
## problem; the player's choice of speed speeds the game's.

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")
const RtsFixture := preload("res://tiamat/modules/rts/test/rts_fixture.gd")
const SCENE := preload("res://tiamat/modules/rts/view/rts_battle_game.tscn")
const MINIGAME := &"fixture_command"

var _ended: Array = []
var _fallen: Array[StringName] = []
var _options: GameOptions

func before_each() -> void:
	_options = GameSettings.options
	_ended.clear()
	_fallen.clear()
	var settings := RtsSettings.new()
	settings.battle_speed = 4.0
	var entries := RtsFixture.entries()
	entries.append(_map())
	entries.append(_minigame())
	ContentFixture.use(self, entries)
	ContentFixture.use_settings(self, [settings])
	RtsEvents.battle_ended.connect(_on_battle_ended)
	RtsEvents.foe_defeated.connect(_on_foe_defeated)

func after_each() -> void:
	InputPrompts.call("_set_using_touch", false)
	GameSettings.reset_controls()
	RtsEvents.battle_ended.disconnect(_on_battle_ended)
	RtsEvents.foe_defeated.disconnect(_on_foe_defeated)
	MiniGameHost.cancel()
	GameSettings.options = _options
	ContentRegistry.active = ContentDB

func test_the_player_selects_with_the_mouse_sends_them_after_the_foe_and_wins() -> void:
	var outcome := {}
	(func() -> void: outcome["result"] = await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	assert_true(get_tree().paused, "the world waits for the battle")
	var first := game.battle.units[0]
	var second := game.battle.units[1]
	var raider := game.battle.units[2]
	game.click(first.position)
	assert_eq(game.get_selection(), [first] as Array[RtsUnit])
	game.click(second.position, true)
	assert_eq(game.get_selection(), [first, second] as Array[RtsUnit], "Shift adds")
	game.click(second.position, true)
	assert_eq(game.get_selection(), [first] as Array[RtsUnit], "and drops")
	game.click(raider.position)
	assert_eq(game.get_selection(), [] as Array[RtsUnit], "a foe is no one to select")
	game.get_field().box_dragged.emit(Rect2(0.0, 0.0, 100.0, 100.0), false)
	assert_eq(game.get_selection(), [first, second] as Array[RtsUnit], "a box takes the units in it")
	game.get_field().right_clicked.emit(raider.position)
	assert_eq([first.order, second.order], [RtsUnit.Order.ATTACK, RtsUnit.Order.ATTACK], "a right click on a foe sends them after it")
	assert_true(await _until(func() -> bool: return outcome.has("result"), 10.0), "the minigame ends a moment after the battle")
	var result: MiniGameResult = outcome["result"]
	assert_true(result.success)
	assert_eq(result.score, 2, "both footmen stand")
	assert_eq(result.data, {"map": &"fixture_meadow"})
	assert_eq(_ended, [[&"fixture_meadow", true]])
	assert_eq(_fallen, [&"fixture_raider"] as Array[StringName])
	assert_false(get_tree().paused)

func test_holding_the_ground_is_told_and_wins() -> void:
	var map := RtsMapData.find(&"fixture_meadow")
	map.goal_area = Rect2(0.0, 30.0, 40.0, 40.0)
	map.goal_seconds = 2.0
	var outcome := {}
	(func() -> void: outcome["result"] = await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	var tells := func(text: String) -> bool: return game.find_children("*", "Label", true, false).any(func(label: Node) -> bool: return (label as Label).text == text)
	assert_true(tells.call(tr("%s: hold the marked ground for %d seconds, or defeat every foe.") % [tr("Fixture Meadow"), 2]), "the first line tells how long")
	assert_true(await _until(func() -> bool: return tells.call(tr("Your units hold the ground.")), 5.0), "and who holds it")
	assert_true(await _until(func() -> bool: return outcome.has("result"), 10.0))
	var result: MiniGameResult = outcome["result"]
	assert_true(result.success, "won with the raider standing")
	assert_eq(result.score, 2)
	assert_eq(_ended, [[&"fixture_meadow", true]])

func test_the_foes_ground_is_told() -> void:
	var map := RtsMapData.find(&"fixture_meadow")
	map.goal_area = Rect2(160.0, 30.0, 40.0, 40.0)
	map.goal_faction_id = FactionData.MONSTERS
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	assert_true(game.find_children("*", "Label", true, false).any(func(label: Node) -> bool: return (label as Label).text == tr("%s: the foes win if they hold the marked ground for %d seconds.") % [tr("Fixture Meadow"), 30]))

func test_the_keys_give_the_commands_and_keep_groups() -> void:
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	var first := game.battle.units[0]
	var second := game.battle.units[1]
	_key(game, KEY_TAB)
	assert_eq(game.get_selection(), [first, second] as Array[RtsUnit], "Tab selects them all")
	_key(game, KEY_H)
	assert_eq([first.order, second.order], [RtsUnit.Order.HOLD, RtsUnit.Order.HOLD])
	_key(game, KEY_S)
	assert_eq([first.order, second.order], [RtsUnit.Order.IDLE, RtsUnit.Order.IDLE])
	_key(game, KEY_A)
	assert_true(game.is_armed())
	game.click(Vector2(100.0, 20.0))
	assert_false(game.is_armed())
	assert_eq([first.order, second.order], [RtsUnit.Order.ATTACK_MOVE, RtsUnit.Order.ATTACK_MOVE], "the click after A picks where they attack-move")
	_key(game, KEY_1, true)
	game.click(Vector2(100.0, 90.0))
	assert_eq(game.get_selection(), [] as Array[RtsUnit], "a click on open ground drops the selection")
	_key(game, KEY_1)
	assert_eq(game.get_selection(), [first, second] as Array[RtsUnit], "the digit takes the group again")
	_key(game, KEY_2)
	assert_eq(game.get_selection(), [first, second] as Array[RtsUnit], "a digit with no group keeps the selection")
	game.click(first.position)
	game.click(first.position)
	assert_eq(game.get_selection(), [first, second] as Array[RtsUnit], "a second click on the only one selected takes its kind")

func test_the_player_rebinds_a_command_and_its_button_names_the_new_key() -> void:
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	var first := game.battle.units[0]
	game.command(RtsBattleGame.Command.SELECT_ALL)
	assert_eq(GameSettings.bindings.get_binding(&"rts_attack_move"), {"key": int(KEY_A)})
	assert_eq(GameSettings.bindings.get_binding(&"move_left"), {"key": int(KEY_A)}, "the battle's commands are read apart from the world's moves")
	assert_true(GameSettings.bind_control(&"rts_hold", {"key": int(KEY_J)}))
	assert_string_contains(_command_button(game, RtsBattleGame.Command.HOLD).text, "[J]")
	_key(game, KEY_H)
	assert_eq(first.order, RtsUnit.Order.IDLE, "H holds no more")
	_key(game, KEY_J)
	assert_eq(first.order, RtsUnit.Order.HOLD)
	assert_true(GameSettings.bind_control(&"rts_stop", {"mouse": int(MOUSE_BUTTON_MIDDLE)}))
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_MIDDLE
	click.pressed = true
	game._input(click)
	assert_eq(first.order, RtsUnit.Order.IDLE, "a command bound to a mouse button")
	InputPrompts.call("_set_using_gamepad", true)
	assert_string_contains(_command_button(game, RtsBattleGame.Command.HOLD).text, "[Y]", "the buttons name the gamepad's in use")
	InputPrompts.call("_set_using_gamepad", false)

func test_the_cursor_selects_and_orders_with_accept_and_interact() -> void:
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	var first := game.battle.units[0]
	var field := game.get_field()
	field.cursor = first.position
	_press(game, &"ui_accept")
	assert_eq(game.get_selection(), [first] as Array[RtsUnit])
	var from := field.cursor
	Input.action_press(&"ui_right")
	await _until(func() -> bool: return field.cursor.x > from.x + 10.0, 2.0)
	Input.action_release(&"ui_right")
	assert_gt(field.cursor.x, from.x + 10.0, "the arrows move the cursor")
	assert_true(field.show_cursor)
	field.cursor = Vector2(60.0, 85.0)
	_press(game, &"interact")
	assert_eq(first.order, RtsUnit.Order.MOVE, "on open ground the selection moves there")
	field.cursor = game.battle.units[2].position
	_press(game, &"interact")
	assert_eq(first.order, RtsUnit.Order.ATTACK, "on a foe it attacks")
	# A arms an attack-move and, though the letters steer here too, moves
	# nothing while held.
	var held := field.cursor
	field.show_cursor = false
	Input.parse_input_event(_physical_key(KEY_A, true))
	var armed := await _until(func() -> bool: return game.is_armed(), 1.0)
	for _frame in 10:
		await get_tree().process_frame
	Input.parse_input_event(_physical_key(KEY_A, false))
	assert_true(armed)
	assert_eq(field.cursor, held)
	assert_false(field.show_cursor)

func test_a_finger_selects_and_orders_with_taps() -> void:
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	InputPrompts.call("_set_using_touch", true)
	var first := game.battle.units[0]
	var raider := game.battle.units[2]
	var field := game.get_field()
	field.clicked.emit(first.position, false, false)
	assert_eq(game.get_selection(), [first] as Array[RtsUnit], "a tap on the player's unit selects it")
	field.clicked.emit(Vector2(60.0, 85.0), false, false)
	assert_eq(first.order, RtsUnit.Order.MOVE, "a tap on open ground sends the selection there")
	assert_eq(game.get_selection(), [first] as Array[RtsUnit], "and keeps it")
	field.clicked.emit(raider.position, false, false)
	assert_eq(first.order, RtsUnit.Order.ATTACK, "a tap on a foe sends it after the foe")
	field.clicked.emit(first.position, false, true)
	assert_eq(game.get_selection().size(), 2, "a second tap on the unit selects every unit of its kind")
	for button: Node in game.find_children("*", "Button", true, false):
		assert_false((button as Button).text.contains("["), "the button names only its command: %s" % (button as Button).text)
	InputPrompts.call("_set_using_touch", false)
	field.clicked.emit(Vector2(60.0, 85.0), false, false)
	assert_eq(game.get_selection(), [] as Array[RtsUnit], "a click on open ground still drops the selection")

func test_a_finger_s_tap_takes_the_nearest_unit_within_half_a_fingertip() -> void:
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	var reach := TouchTarget.reach
	TouchTarget.reach = 24.0 * game.get_field().get_zoom()
	var first := game.battle.units[0]
	var beside := first.position + Vector2(first.data.radius + 8.0, 0.0)
	game.get_field().clicked.emit(beside, false, false)
	assert_eq(game.get_selection(), [] as Array[RtsUnit], "a click there misses it")
	InputPrompts.call("_set_using_touch", true)
	assert_eq(game.get_pick_slack(), 12.0, "half a fingertip, in pixels of the field")
	game.get_field().clicked.emit(beside, false, false)
	assert_eq(game.get_selection(), [first] as Array[RtsUnit], "a finger's tap takes it")
	TouchTarget.reach = 0.0
	assert_eq(game.get_pick_slack(), RtsBattleGame.PICK_SLACK, "with no fingertip measured, as a click")
	TouchTarget.reach = reach
	InputPrompts.call("_set_using_touch", false)

func test_a_finger_that_wanders_a_little_taps_rather_than_drags_a_box() -> void:
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var field := _game().get_field()
	var reach := TouchTarget.reach
	TouchTarget.reach = 40.0
	var taps: Array[Vector2] = []
	var boxes: Array[Rect2] = []
	field.clicked.connect(func(point: Vector2, _additive: bool, _double: bool) -> void: taps.append(point))
	field.box_dragged.connect(func(rect: Rect2, _additive: bool) -> void: boxes.append(rect))
	var start := field.to_screen(Vector2(40.0, 40.0))
	_press_and_move(field, start, start + Vector2(8.0, 0.0))
	assert_eq([taps.size(), boxes.size()], [0, 1], "with the mouse, eight pixels drag a box")
	InputPrompts.call("_set_using_touch", true)
	assert_eq(field.get_drag_pixels(), 14.0)
	_press_and_move(field, start, start + Vector2(8.0, 0.0))
	assert_eq([taps.size(), boxes.size()], [1, 1], "a finger wandering as far taps")
	_press_and_move(field, start, start + Vector2(30.0, 20.0))
	assert_eq([taps.size(), boxes.size()], [1, 2], "and further drags a box")
	TouchTarget.reach = reach
	InputPrompts.call("_set_using_touch", false)

func test_a_selection_of_one_kind_tells_what_it_is_strong_against() -> void:
	RtsUnitData.find(&"fixture_footman").strong_against.assign([&"fixture_raider", &"fixture_brute"])
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	_key(game, KEY_TAB)
	var told := tr("%d selected: %s") % [2, "%s ×2" % tr("Fixture Footman")] + " " + tr("(strong against %s)") % GameText.list(PackedStringArray([tr("Fixture Raider"), tr("Fixture Brute")]))
	assert_true(game.find_children("*", "Label", true, false).any(func(label: Node) -> bool: return (label as Label).text == told), "the selection tells: %s" % told)

func test_a_selected_unit_that_strikes_from_afar_shows_how_far() -> void:
	var field: RtsBattleField = autofree(RtsBattleField.new())
	var battle := RtsFixture.battle()
	var footman := RtsFixture.add(battle, &"fixture_footman", FactionData.PLAYER, Vector2(20.0, 20.0))
	var bowman := RtsFixture.add(battle, &"fixture_bowman", FactionData.PLAYER, Vector2(40.0, 20.0))
	field.show_battle(battle)
	assert_true(field.get_range_rings().is_empty(), "nothing selected")
	field.selection.assign([footman, bowman])
	var rings := field.get_range_rings()
	assert_eq(rings.keys(), [bowman], "a footman strikes at its edge")
	assert_eq(rings.get(bowman), 54.0, "the bowman reaches 50 past its edge, 4 from its middle")

func test_cancel_drops_the_armed_move_then_the_selection_then_gives_up() -> void:
	var outcome := {}
	(func() -> void: outcome["result"] = await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	game.command(RtsBattleGame.Command.SELECT_ALL)
	game.command(RtsBattleGame.Command.ATTACK_MOVE)
	_press(game, &"ui_cancel")
	assert_false(game.is_armed())
	assert_eq(game.get_selection().size(), 2)
	_press(game, &"ui_cancel")
	assert_eq(game.get_selection().size(), 0)
	_press(game, &"ui_cancel")
	assert_false(game.battle.is_over(), "one cancel with nothing to drop only asks")
	_press(game, &"ui_cancel")
	assert_true(game.battle.is_over())
	assert_true(await _until(func() -> bool: return outcome.has("result")))
	var result: MiniGameResult = outcome["result"]
	assert_false(result.success)
	assert_false(result.cancelled, "giving up loses the battle")
	assert_eq(_ended, [[&"fixture_meadow", false]])

func test_an_unknown_map_ends_the_minigame_at_once_and_is_a_content_problem() -> void:
	var definition := MiniGameDefinition.find(MINIGAME)
	assert_eq(definition.find_problems(ContentRegistry.active), PackedStringArray())
	var outcome := {}
	(func() -> void: outcome["result"] = await MiniGameHost.run(MINIGAME, {"map": "fixture_nowhere"})).call()
	assert_true(await _until(func() -> bool: return outcome.has("result")))
	assert_false((outcome["result"] as MiniGameResult).success)
	assert_false(MiniGameHost.is_running())
	definition.settings = {"map": "fixture_nowhere"}
	assert_eq(definition.find_problems(ContentRegistry.active), PackedStringArray(["sets unknown command map 'fixture_nowhere'"]))

func test_a_definition_s_score_goals_ask_for_no_more_units_than_the_player_fields() -> void:
	var definition := MiniGameDefinition.find(MINIGAME)
	definition.score_name = "Units Left"
	definition.score_goals = PackedInt32Array([1, 2])
	assert_eq(definition.find_problems(ContentRegistry.active), PackedStringArray(), "two footmen")
	definition.score_goals = PackedInt32Array([2, 3])
	assert_eq(definition.find_problems(ContentRegistry.active), PackedStringArray(["asks for a score of 3, but 2 is the most it can give"]))

func test_the_player_chooses_how_fast_a_battle_runs() -> void:
	GameSettings.options = GameOptions.new(RtsModule.new().get_options())
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	assert_eq(GameSettings.get_option(RtsBattleGame.SPEED_OPTION), "Standard", "the module offers the choice, standard at first")
	assert_eq(game.get_speed(), 4.0, "the game's speed")
	GameSettings.options.set_value(RtsBattleGame.SPEED_OPTION, "Slow")
	assert_eq(game.get_speed(), 2.0, "read as the battle runs")
	GameSettings.options.set_value(RtsBattleGame.SPEED_OPTION, "Fast")
	assert_eq(game.get_speed(), 6.0)
	GameSettings.options = GameOptions.new()
	assert_eq(game.get_speed(), 4.0, "a game without the option keeps its speed")

func test_the_player_chooses_how_strong_the_foes_are() -> void:
	GameSettings.options = GameOptions.new(RtsModule.new().get_options())
	assert_eq(GameSettings.get_option(RtsBattleGame.FOE_STRENGTH_OPTION), "Standard", "the module offers the choice, standard at first")
	GameSettings.options.set_value(RtsBattleGame.FOE_STRENGTH_OPTION, "Strong")
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var battle := _game().battle
	var foes := 0
	for unit: RtsUnit in battle.units:
		var foe := FactionData.are_hostile(unit.faction, battle.player_faction)
		foes += 1 if foe else 0
		assert_eq(unit.health.maximum, roundi(unit.data.max_health * 1.5) if foe else unit.data.max_health, "a foe starts stronger, the player's side as it is")
	assert_gt(foes, 0)
	GameSettings.options = GameOptions.new()

# The minigame the host runs now; the one the last test cancelled may still
# wait to be freed.
# A left press at `from`, a move to `to` and the release there, as the field
# takes them.
func _press_and_move(field: RtsBattleField, from: Vector2, to: Vector2) -> void:
	var press := InputEventMouseButton.new()
	press.button_index = MOUSE_BUTTON_LEFT
	press.pressed = true
	press.position = from
	field._gui_input(press)
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = to
	field._gui_input(motion)
	var release := InputEventMouseButton.new()
	release.button_index = MOUSE_BUTTON_LEFT
	release.position = to
	field._gui_input(release)

func _game() -> RtsBattleGame:
	for node: Node in get_tree().root.find_children("*", "RtsBattleGame", true, false):
		if not node.is_queued_for_deletion():
			return node as RtsBattleGame
	return null

func _press(game: RtsBattleGame, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	game._unhandled_input(event)

# A key press as the tree hands it to the minigame, first as input, then as
# unhandled input; no key here is read by both.
func _key(game: RtsBattleGame, key: Key, control := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.ctrl_pressed = control
	event.pressed = true
	game._input(event)
	game._unhandled_input(event)

func _command_button(game: RtsBattleGame, which: RtsBattleGame.Command) -> Button:
	return game.get("_buttons")[which] as Button

func _physical_key(key: Key, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.pressed = pressed
	return event

# Whether `condition` holds within `seconds`. GUT's own waits stop while the
# world is paused, as it is for a minigame; the tree's frames go on.
func _until(condition: Callable, seconds := 5.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > end:
			return false
		await get_tree().process_frame
	return true

func _on_battle_ended(rts_map_id: StringName, won: bool) -> void:
	_ended.append([rts_map_id, won])

func _on_foe_defeated(rts_unit_id: StringName) -> void:
	_fallen.append(rts_unit_id)

# Two footmen at the left, a raider that waits at the right.
func _map() -> RtsMapData:
	var map := RtsMapData.new()
	map.id = &"fixture_meadow"
	map.display_name = "Fixture Meadow"
	map.size = Vector2(200.0, 100.0)
	map.computer_advances = false
	map.placements.assign([
		RtsFixture.placement(&"fixture_footman", FactionData.PLAYER, Vector2(20.0, 40.0)),
		RtsFixture.placement(&"fixture_footman", FactionData.PLAYER, Vector2(20.0, 60.0)),
		RtsFixture.placement(&"fixture_raider", FactionData.MONSTERS, Vector2(180.0, 50.0)),
	])
	return map

func _minigame() -> MiniGameDefinition:
	var minigame := MiniGameDefinition.new()
	minigame.id = MINIGAME
	minigame.scene = SCENE
	minigame.settings = {"map": "fixture_meadow"}
	return minigame
