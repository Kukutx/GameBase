extends GutTest

## The tactics module's minigame (`GridBattleGame`) run by `MiniGameHost`: the
## player commands their unit with the command buttons and the board, wins,
## and the battle's end is told; the commands follow what the foes do
## meanwhile; a finger's tap on a cell shows it and a second tap picks it;
## cancel twice gives the battle up; an unknown map ends it at once,
## and a definition that names one is a content problem; the player's choice
## of speed speeds the game's.

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")
const TacticsFixture := preload("res://tiamat/modules/tactics/test/tactics_fixture.gd")
const SCENE := preload("res://tiamat/modules/tactics/view/grid_battle_game.tscn")
const MINIGAME := &"fixture_battle"

var _ended: Array = []
var _options: GameOptions

func before_each() -> void:
	_options = GameSettings.options
	_ended.clear()
	var settings := TacticsSettings.new()
	settings.battle_speed = 4.0
	var entries := TacticsFixture.entries()
	# Slow enough that it never acts before the knight is done with it.
	entries.append(TacticsFixture.unit(&"fixture_dummy", 6, 0, 0, 1.0, 0, [&"fixture_strike"]))
	entries.append(_map())
	entries.append(_minigame())
	ContentFixture.use(self, entries)
	ContentFixture.use_settings(self, [settings])
	TacticsEvents.battle_ended.connect(_on_battle_ended)

func after_each() -> void:
	InputPrompts.call("_set_using_touch", false)
	TacticsEvents.battle_ended.disconnect(_on_battle_ended)
	MiniGameHost.cancel()
	GameSettings.options = _options
	ContentRegistry.active = ContentDB

func test_the_player_moves_strikes_and_wins() -> void:
	var outcome := {}
	(func() -> void: outcome["result"] = await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	assert_true(await _until(func() -> bool: return game.get_mode() == GridBattleGame.Mode.COMMAND), "the knight's turn comes")
	assert_true(get_tree().paused, "the world waits for the battle")
	game.choose_command(0)
	assert_eq(game.get_mode(), GridBattleGame.Mode.PICK_MOVE)
	assert_true(game.get_board().choices.has(Vector2i(1, 1)))
	game.get_board().cell_clicked.emit(Vector2i(1, 1))
	assert_eq(game.battle.get_turn_unit().cell, Vector2i(1, 1), "a click on a cell moves the knight there")
	assert_eq(game.get_mode(), GridBattleGame.Mode.COMMAND, "its action is still to take")
	game.choose_command(1)
	assert_eq(game.get_mode(), GridBattleGame.Mode.PICK_TARGET)
	assert_eq(game.get_board().choices, [Vector2i(2, 1)] as Array[Vector2i])
	game.pick(Vector2i(2, 1))
	assert_true(await _until(func() -> bool: return outcome.has("result")), "the minigame ends a moment after the battle")
	var result: MiniGameResult = outcome["result"]
	assert_true(result.success)
	assert_eq(result.score, 1, "the knight stands")
	assert_eq(result.data, {"map": &"fixture_field"})
	assert_eq(_ended, [[&"fixture_field", true]])
	assert_false(get_tree().paused)

func test_the_commands_follow_what_the_foes_do_meanwhile() -> void:
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	assert_true(await _until(func() -> bool: return game.get_mode() == GridBattleGame.Mode.COMMAND))
	game.choose_command(1)
	assert_eq(game.get_mode(), GridBattleGame.Mode.COMMAND, "nothing in reach to strike")
	# The dummy steps up, as a foe does while time flows.
	var dummy := game.battle.get_unit_at(Vector2i(2, 1))
	dummy.cell = Vector2i(1, 1)
	game.battle.unit_moved.emit(dummy, [Vector2i(2, 1), Vector2i(1, 1)] as Array[Vector2i])
	game.choose_command(1)
	assert_eq(game.get_mode(), GridBattleGame.Mode.PICK_TARGET)
	assert_eq(game.get_board().choices, [Vector2i(1, 1)] as Array[Vector2i])

func test_a_finger_shows_a_cell_then_picks_it_on_a_second_tap() -> void:
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	assert_true(await _until(func() -> bool: return game.get_mode() == GridBattleGame.Mode.COMMAND), "the knight's turn comes")
	InputPrompts.call("_set_using_touch", true)
	game.choose_command(0)
	var board := game.get_board()
	var cell := Vector2i(1, 1)
	assert_true(board.choices.has(cell) and board.cursor != cell)
	assert_true(_shows(game, tr("Tap where it moves, then tap it again. × goes back.")), "the hint tells to tap twice")
	board.cell_clicked.emit(cell)
	assert_eq(board.cursor, cell, "a first tap shows the cell")
	assert_eq(game.battle.get_turn_unit().cell, Vector2i(0, 1), "and moves no one")
	board.cell_clicked.emit(cell)
	assert_eq(game.battle.get_turn_unit().cell, cell, "a second tap moves the knight there")
	InputPrompts.call("_set_using_touch", false)
	game.choose_command(1)
	assert_true(_shows(game, tr("Pick what it aims at. Cancel goes back.")), "the hint follows the device in use")

func test_a_definition_names_a_known_map() -> void:
	var definition := MiniGameDefinition.find(MINIGAME)
	assert_eq(definition.find_problems(ContentRegistry.active), PackedStringArray())
	definition.settings = {"map": "fixture_nowhere"}
	assert_eq(definition.find_problems(ContentRegistry.active), PackedStringArray(["sets unknown battle map 'fixture_nowhere'"]))

func test_a_definition_s_score_goals_ask_for_no_more_units_than_the_player_fields() -> void:
	var definition := MiniGameDefinition.find(MINIGAME)
	definition.score_name = "Units Left"
	definition.score_goals = PackedInt32Array([1])
	assert_eq(definition.find_problems(ContentRegistry.active), PackedStringArray(), "the knight alone")
	definition.score_goals = PackedInt32Array([1, 2])
	assert_eq(definition.find_problems(ContentRegistry.active), PackedStringArray(["asks for a score of 2, but 1 is the most it can give"]))
	var joining := TacticsFixture.placement(&"fixture_knight", FactionData.PLAYER, Vector2i(0, 0))
	joining.condition = "MINIGAME_WON %s" % MINIGAME
	BattleMapData.find(&"fixture_field").placements.append(joining)
	assert_eq(definition.find_problems(ContentRegistry.active), PackedStringArray(), "a unit that joins on a condition counts")

func test_cancel_twice_gives_the_battle_up() -> void:
	var outcome := {}
	(func() -> void: outcome["result"] = await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	await _until(func() -> bool: return game.get_mode() == GridBattleGame.Mode.COMMAND)
	game.choose_command(0)
	_press(game, &"ui_cancel")
	assert_eq(game.get_mode(), GridBattleGame.Mode.COMMAND, "cancel goes back to the commands first")
	_press(game, &"ui_cancel")
	assert_false(game.battle.is_over(), "one cancel only asks")
	_press(game, &"ui_cancel")
	assert_true(game.battle.is_over())
	assert_true(await _until(func() -> bool: return outcome.has("result")))
	var result: MiniGameResult = outcome["result"]
	assert_false(result.success)
	assert_false(result.cancelled, "giving up loses the battle")
	assert_eq(_ended, [[&"fixture_field", false]])

func test_an_unknown_map_ends_the_minigame_at_once() -> void:
	var outcome := {}
	(func() -> void: outcome["result"] = await MiniGameHost.run(MINIGAME, {"map": "fixture_nowhere"})).call()
	assert_true(await _until(func() -> bool: return outcome.has("result")))
	assert_false((outcome["result"] as MiniGameResult).success)
	assert_false(MiniGameHost.is_running())

func test_the_player_chooses_how_fast_a_battle_runs() -> void:
	GameSettings.options = GameOptions.new(TacticsModule.new().get_options())
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	assert_eq(GameSettings.get_option(GridBattleGame.SPEED_OPTION), "Standard", "the module offers the choice, standard at first")
	assert_eq(game.get_speed(), 4.0, "the game's speed")
	GameSettings.options.set_value(GridBattleGame.SPEED_OPTION, "Slow")
	assert_eq(game.get_speed(), 2.0, "read as the battle runs")
	GameSettings.options.set_value(GridBattleGame.SPEED_OPTION, "Fast")
	assert_eq(game.get_speed(), 6.0)
	GameSettings.options = GameOptions.new()
	assert_eq(game.get_speed(), 4.0, "a game without the option keeps its speed")

func test_the_player_chooses_how_strong_the_foes_are() -> void:
	GameSettings.options = GameOptions.new(TacticsModule.new().get_options())
	assert_eq(GameSettings.get_option(GridBattleGame.FOE_STRENGTH_OPTION), "Standard", "the module offers the choice, standard at first")
	GameSettings.options.set_value(GridBattleGame.FOE_STRENGTH_OPTION, "Strong")
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var battle := _game().battle
	var foes := 0
	for unit: GridUnit in battle.units:
		var foe := FactionData.are_hostile(unit.faction, battle.player_faction)
		foes += 1 if foe else 0
		assert_eq(unit.health.maximum, roundi(unit.data.max_health * 1.5) if foe else unit.data.max_health, "a foe starts stronger, the player's side as it is")
	assert_gt(foes, 0)
	GameSettings.options = GameOptions.new()

# The minigame the host runs now; the one the last test cancelled may still
# wait to be freed.
func _game() -> GridBattleGame:
	for node: Node in get_tree().root.find_children("*", "GridBattleGame", true, false):
		if not node.is_queued_for_deletion():
			return node as GridBattleGame
	return null

# Whether a label of `game` reads `text`.
func _shows(game: GridBattleGame, text: String) -> bool:
	return game.find_children("*", "Label", true, false).any(func(label: Node) -> bool: return (label as Label).text == text)

func _press(game: GridBattleGame, action: StringName) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	game._unhandled_input(event)

# Whether `condition` holds within `seconds`. GUT's own waits stop while the
# world is paused, as it is for a minigame; the tree's frames go on.
func _until(condition: Callable, seconds := 5.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > end:
			return false
		await get_tree().process_frame
	return true

func _on_battle_ended(battle_map_id: StringName, won: bool) -> void:
	_ended.append([battle_map_id, won])

# The knight at the left, the dummy two cells to its right.
func _map() -> BattleMapData:
	var map := BattleMapData.new()
	map.id = &"fixture_field"
	map.display_name = "Fixture Field"
	map.size = Vector2i(4, 3)
	map.placements.assign([
		TacticsFixture.placement(&"fixture_knight", FactionData.PLAYER, Vector2i(0, 1)),
		TacticsFixture.placement(&"fixture_dummy", FactionData.MONSTERS, Vector2i(2, 1)),
	])
	return map

func _minigame() -> MiniGameDefinition:
	var minigame := MiniGameDefinition.new()
	minigame.id = MINIGAME
	minigame.scene = SCENE
	minigame.settings = {"map": "fixture_field"}
	return minigame
