extends GutTest

## The tactics module's minigame (`GridBattleGame`) run by `MiniGameHost`: the
## player commands their unit with the command buttons and the board, wins,
## and the battle's end is told; the commands follow what the foes do
## meanwhile; cancel twice gives the battle up; an unknown map ends it at once,
## and a definition that names one is a content problem.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const TacticsFixture := preload("res://gamebase/modules/tactics/test/tactics_fixture.gd")
const SCENE := preload("res://gamebase/modules/tactics/view/grid_battle_game.tscn")
const MINIGAME := &"fixture_battle"

var _ended: Array = []

func before_each() -> void:
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
	TacticsEvents.battle_ended.disconnect(_on_battle_ended)
	MiniGameHost.cancel()
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

func test_a_definition_names_a_known_map() -> void:
	var definition := MiniGameDefinition.find(MINIGAME)
	assert_eq(definition.find_problems(ContentRegistry.active), PackedStringArray())
	definition.settings = {"map": "fixture_nowhere"}
	assert_eq(definition.find_problems(ContentRegistry.active), PackedStringArray(["sets unknown battle map 'fixture_nowhere'"]))

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

# The minigame the host runs now; the one the last test cancelled may still
# wait to be freed.
func _game() -> GridBattleGame:
	for node: Node in get_tree().root.find_children("*", "GridBattleGame", true, false):
		if not node.is_queued_for_deletion():
			return node as GridBattleGame
	return null

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
