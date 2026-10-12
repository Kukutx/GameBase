extends GutTest

## The rts module's minigame (`RtsBattleGame`) run by `MiniGameHost`: the
## player selects their units with clicks and a box and sends them after a
## foe with a right click, wins, and the battle's end is told; the keys give
## the commands and keep groups; the cursor selects and orders with accept and
## interact, and a command key that also steers leaves it be; cancel drops an
## armed attack-move, then the selection, and twice gives the battle up; an
## unknown map ends it at once, and a definition that names one is a content
## problem.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const RtsFixture := preload("res://gamebase/modules/rts/test/rts_fixture.gd")
const SCENE := preload("res://gamebase/modules/rts/view/rts_battle_game.tscn")
const MINIGAME := &"fixture_command"

var _ended: Array = []
var _fallen: Array[StringName] = []

func before_each() -> void:
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
	RtsEvents.battle_ended.disconnect(_on_battle_ended)
	RtsEvents.foe_defeated.disconnect(_on_foe_defeated)
	MiniGameHost.cancel()
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

# The minigame the host runs now; the one the last test cancelled may still
# wait to be freed.
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

func _key(game: RtsBattleGame, key: Key, control := false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = key
	event.keycode = key
	event.ctrl_pressed = control
	event.pressed = true
	game._unhandled_input(event)

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
