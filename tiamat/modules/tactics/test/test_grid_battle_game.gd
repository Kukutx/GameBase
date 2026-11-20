extends GutTest

## The tactics module's minigame (`GridBattleGame`) run by `MiniGameHost`: the
## player commands their unit with the command buttons and the board, wins,
## and the battle's end is told; once the unit moved, Move takes the move
## back; the commands follow what the foes do meanwhile, and an action that
## recharges tells when it is ready; a goal is told and taking it wins; a
## unit that arrives is told, and so is an affliction and each of its ticks,
## and what a heal that cures lifts; a
## finger's tap on a cell shows it and a second tap picks it;
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
	var board := game.get_board()
	var order := game.battle.get_turn_order(board.turns_shown)
	var firsts: Dictionary[GridUnit, int] = {}
	for index in order.size():
		if not firsts.has(order[index]):
			firsts[order[index]] = index + 1
	assert_eq(order.size(), board.turns_shown)
	assert_eq(board.get_turn_marks(), firsts, "the board numbers the units whose turns come next, each by its first")
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

func test_once_moved_the_move_command_takes_the_move_back() -> void:
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	assert_true(await _until(func() -> bool: return game.get_mode() == GridBattleGame.Mode.COMMAND), "the knight's turn comes")
	var knight := game.battle.get_turn_unit()
	game.choose_command(0)
	game.pick(Vector2i(1, 1))
	var buttons := _commands(game)
	assert_eq(buttons[0].text, tr("Undo Move"))
	assert_false(buttons[0].disabled)
	assert_true(buttons[1].has_focus(), "the keys start on the action, not on taking the move back")
	game.choose_command(0)
	assert_eq(knight.cell, Vector2i(0, 1), "the knight stands where its turn found it")
	assert_eq(game.get_mode(), GridBattleGame.Mode.COMMAND)
	assert_true(_shows(game, tr("%s steps back.") % tr(knight.data.display_name)))
	assert_eq(_commands(game)[0].text, tr("Move"), "and may move again")
	game.choose_command(0)
	assert_eq(game.get_mode(), GridBattleGame.Mode.PICK_MOVE)

func test_picking_a_move_marks_where_the_foes_could_strike() -> void:
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	assert_true(await _until(func() -> bool: return game.get_mode() == GridBattleGame.Mode.COMMAND), "the knight's turn comes")
	var board := game.get_board()
	assert_true(board.danger.is_empty(), "nothing marked while the player picks a command")
	game.choose_command(0)
	var danger := board.danger.duplicate()
	danger.sort()
	assert_eq(danger, [Vector2i(1, 1), Vector2i(2, 0), Vector2i(2, 2), Vector2i(3, 1)] as Array[Vector2i], "the dummy stands still and strikes one away")
	var warns := func() -> bool: return game.find_children("*", "Label", true, false).any(func(label: Node) -> bool: return (label as Label).text.contains(tr("Foes can strike here.")))
	board.cell_hovered.emit(Vector2i(1, 1))
	assert_true(warns.call(), "the side says so of the cell picked")
	board.cell_hovered.emit(Vector2i(0, 0))
	assert_false(warns.call())
	_press(game, &"ui_cancel")
	assert_eq(game.get_mode(), GridBattleGame.Mode.COMMAND)
	assert_true(board.danger.is_empty(), "gone once the player goes back to the commands")

func test_aiming_tells_what_the_action_would_do() -> void:
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	assert_true(await _until(func() -> bool: return game.get_mode() == GridBattleGame.Mode.COMMAND), "the knight's turn comes")
	game.choose_command(0)
	game.pick(Vector2i(1, 1))
	game.choose_command(1)
	assert_eq(game.get_mode(), GridBattleGame.Mode.PICK_TARGET)
	var dummy := game.battle.get_unit_at(Vector2i(2, 1))
	var told := tr("%s takes %d and falls") % [tr(dummy.data.display_name), 6]
	var tells := func(text: String) -> bool: return game.find_children("*", "Label", true, false).any(func(label: Node) -> bool: return (label as Label).text.contains(text))
	assert_true(tells.call(told), "7 would take the dummy's last 6")
	assert_eq(dummy.health.current, 6, "told, not done")
	game.get_board().cell_hovered.emit(Vector2i(0, 0))
	assert_false(tells.call(told), "only while the cursor is on a cell to aim at")

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

func test_a_unit_with_many_commands_leaves_the_line_under_the_board_in_view() -> void:
	BattleUnitData.find(&"fixture_knight").action_ids.assign([&"fixture_strike", &"fixture_shot", &"fixture_blast", &"fixture_mend"])
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	assert_true(await _until(func() -> bool: return game.get_mode() == GridBattleGame.Mode.COMMAND), "the knight's turn comes")
	await get_tree().process_frame
	assert_eq(_commands(game).size(), 6, "Move, four actions and End Turn")
	var view := game.get_viewport().get_visible_rect()
	var line := game.find_children("*", "Label", true, false).filter(func(label: Node) -> bool: return (label as Label).text == tr("%s's turn.") % tr("Fixture Knight"))
	assert_eq(line.size(), 1)
	assert_true((line[0] as Label).get_global_rect().end.y <= view.end.y + 0.5, "the message stays in view: %s of %s" % [(line[0] as Label).get_global_rect(), view])
	_commands(game)[-1].grab_focus()
	await get_tree().process_frame
	assert_true(_commands(game)[-1].get_global_rect().end.y <= view.end.y + 0.5, "the side scrolls to the focused command")

func test_a_leader_is_told_and_its_fall_routs_its_side() -> void:
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	assert_true(await _until(func() -> bool: return game.get_mode() == GridBattleGame.Mode.COMMAND), "the knight's turn comes")
	var dummy := game.battle.get_unit_at(Vector2i(2, 1))
	dummy.leader = true
	game.choose_command(0)
	game.pick(Vector2i(1, 1))
	game.choose_command(1)
	game.get_board().cell_hovered.emit(Vector2i(2, 1))
	var dummy_name := tr(dummy.data.display_name)
	var tells := func(text: String) -> bool: return game.find_children("*", "Label", true, false).any(func(label: Node) -> bool: return (label as Label).text.contains(text))
	assert_true(tells.call(tr("Leader: their side flees when they fall")), "the side tells the leader")
	assert_true(tells.call(tr("%s takes %d and falls; their side flees") % [dummy_name, 6]))
	var told := []
	game.battle.unit_defeated.connect(func(_unit: GridUnit) -> void: told.append(_shows(game, tr("%s falls, and their side flees!") % dummy_name)))
	game.pick(Vector2i(2, 1))
	assert_eq(told, [true], "the message tells the rout")

func test_a_goal_is_told_and_taking_it_wins() -> void:
	BattleMapData.find(&"fixture_field").goal_cells.assign([Vector2i(1, 0)])
	var outcome := {}
	(func() -> void: outcome["result"] = await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	assert_true(await _until(func() -> bool: return game.get_mode() == GridBattleGame.Mode.COMMAND), "the knight's turn comes")
	game.choose_command(0)
	game.get_board().cell_hovered.emit(Vector2i(1, 0))
	var tells := func(text: String) -> bool: return game.find_children("*", "Label", true, false).any(func(label: Node) -> bool: return (label as Label).text.contains(text))
	assert_true(tells.call(tr("Goal: end a turn here to win")), "the side tells the goal")
	game.pick(Vector2i(1, 0))
	game.choose_command(2)
	assert_true(_shows(game, "%s %s" % [tr("%s takes the goal!") % tr("Fixture Knight"), tr("Victory!")]), "the message tells who took it")
	assert_true(await _until(func() -> bool: return outcome.has("result")))
	assert_true((outcome["result"] as MiniGameResult).success, "won with the dummy standing")
	assert_eq(_ended, [[&"fixture_field", true]])

func test_a_unit_that_arrives_is_told() -> void:
	var late := TacticsFixture.placement(&"fixture_dummy", FactionData.MONSTERS, Vector2i(3, 0))
	late.arrive_seconds = 1.0
	BattleMapData.find(&"fixture_field").placements.append(late)
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	assert_eq(game.battle.arrivals.size(), 1, "on its way")
	assert_true(await _until(func() -> bool: return _shows(game, tr("%s joins the foes!") % tr("Fixture Dummy"))))
	assert_eq(game.battle.get_unit_at(Vector2i(3, 0)).data.id, &"fixture_dummy")

func test_a_time_limit_is_told_counted_down_and_won_by_holding_out() -> void:
	BattleMapData.find(&"fixture_field").time_limit = 1.0
	var outcome := {}
	(func() -> void: outcome["result"] = await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	assert_true(_tells(game, tr("Hold out for %d seconds of battle.") % 1), "the line tells how long")
	assert_true(_tells(game, tr("Hold out: %d s") % 1), "the side counts it down")
	assert_true(await _until(func() -> bool: return _tells(game, "%s %s" % [tr("Time is up!"), game.get_outcome_text(true)])), "time runs out before the knight's turn")
	assert_true(await _until(func() -> bool: return outcome.has("result")))
	var result: MiniGameResult = outcome["result"]
	assert_true(result.success, "won with the dummy standing")
	assert_eq(_ended, [[&"fixture_field", true]])

func test_aiming_a_delay_tells_it_sets_the_turn_back() -> void:
	BattleUnitData.find(&"fixture_knight").action_ids.assign([&"fixture_bash"])
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	assert_true(await _until(func() -> bool: return game.get_mode() == GridBattleGame.Mode.COMMAND), "the knight's turn comes")
	game.choose_command(0)
	game.pick(Vector2i(1, 1))
	var dummy := game.battle.get_unit_at(Vector2i(2, 1))
	dummy.gauge = 60.0
	game.choose_command(1)
	game.get_board().cell_hovered.emit(Vector2i(2, 1))
	assert_true(game.find_children("*", "Label", true, false).any(func(label: Node) -> bool: return (label as Label).text.contains(tr("%s takes %d, turn delayed") % [tr(dummy.data.display_name), 5])), "1 and the knight's 4 leave the dummy standing, its turn set back")

func test_aiming_a_boost_tells_what_it_gives_and_the_unit_then_shows_it() -> void:
	BattleUnitData.find(&"fixture_knight").action_ids.assign([&"fixture_rally", &"fixture_hex"])
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	assert_true(await _until(func() -> bool: return game.get_mode() == GridBattleGame.Mode.COMMAND), "the knight's turn comes")
	var knight := game.battle.get_turn_unit()
	game.choose_command(0)
	game.pick(Vector2i(1, 1))
	game.choose_command(2)
	game.get_board().cell_hovered.emit(Vector2i(2, 1))
	assert_true(_tells(game, tr("%s takes %d") % [tr("Fixture Dummy"), 5] + ", " + tr("Defense %s") % "-2"), "1 and the knight's 4, and the curse")
	_press(game, &"ui_cancel")
	game.choose_command(1)
	game.get_board().cell_hovered.emit(knight.cell)
	assert_true(_tells(game, tr("%s gains %s") % [tr("Fixture Knight"), tr("Attack %s") % "+2"]), "a rally that heals nothing tells only its boost")
	game.pick(knight.cell)
	assert_true(await _until(func() -> bool: return knight.turns_taken == 2 and game.get_mode() == GridBattleGame.Mode.COMMAND), "the knight's next turn comes")
	assert_true(_tells(game, tr("Attack %d · Defense %d · Move %d") % [6, 2, 3]), "the knight's attack with the boost")
	assert_true(_tells(game, tr("Boosts: %s (turns left: %d)") % [tr("Attack %s") % "+2", 1]), "through this turn and one more")

func test_aiming_an_affliction_tells_it_and_each_tick_is_told() -> void:
	BattleUnitData.find(&"fixture_knight").action_ids.assign([&"fixture_venom"])
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	assert_true(await _until(func() -> bool: return game.get_mode() == GridBattleGame.Mode.COMMAND), "the knight's turn comes")
	game.choose_command(0)
	game.pick(Vector2i(1, 1))
	game.choose_command(1)
	game.get_board().cell_hovered.emit(Vector2i(2, 1))
	assert_true(_tells(game, tr("%s takes %d") % [tr("Fixture Dummy"), 4] + ", " + tr("Fixture Poison")), "the knight's 4, and the poison")
	game.pick(Vector2i(2, 1))
	assert_true(await _until(func() -> bool: return _shows(game, tr("%s takes %d from %s.") % [tr("Fixture Dummy"), 1, tr("Fixture Poison")])), "each tick is told")

func test_aiming_a_heal_that_cures_tells_what_it_lifts() -> void:
	BattleUnitData.find(&"fixture_knight").action_ids.assign([&"fixture_mend"])
	BattleActionData.find(&"fixture_mend").cures = true
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	assert_true(await _until(func() -> bool: return game.get_mode() == GridBattleGame.Mode.COMMAND), "the knight's turn comes")
	var knight := game.battle.get_turn_unit()
	knight.health.take(3)
	assert_true(knight.afflict(AfflictionData.find(&"fixture_poison"), FactionData.MONSTERS))
	game.choose_command(0)
	game.pick(Vector2i(1, 1))
	game.choose_command(1)
	game.get_board().cell_hovered.emit(Vector2i(1, 1))
	assert_true(_tells(game, tr("%s regains %d") % [tr("Fixture Knight"), 3] + ", " + tr("cures %s") % tr("Fixture Poison")), "the knight's 3, and the poison it lifts")
	assert_true(_tells(game, tr("Afflicted: %s") % (tr("%s %ds") % [tr("Fixture Poison"), 4])), "the knight's poison and the seconds it lasts yet")

func test_an_action_that_recharges_tells_when_it_is_ready() -> void:
	BattleUnitData.find(&"fixture_knight").action_ids.assign([&"fixture_strike", &"fixture_volley"])
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var game := _game()
	assert_true(await _until(func() -> bool: return game.get_mode() == GridBattleGame.Mode.COMMAND), "the knight's turn comes")
	var knight := game.battle.get_turn_unit()
	var volley := BattleActionData.find(&"fixture_volley")
	assert_eq(_commands(game)[2].text, tr("Fixture Volley"))
	# As if it loosed the volley on its last turn.
	knight.use(volley)
	knight.start_turn()
	game.battle.unit_moved.emit(knight, [] as Array[Vector2i])
	assert_eq(_commands(game)[2].text, tr("%s (ready in %d)") % [tr("Fixture Volley"), 2], "it tells in how many of the knight's turns")
	assert_true(_commands(game)[2].disabled)

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

# The command buttons of `game`, as listed.
func _commands(game: GridBattleGame) -> Array[Button]:
	var buttons: Array[Button] = []
	buttons.assign(game.find_children("*", "Button", true, false))
	return buttons

# Whether a label of `game` reads `text`.
func _shows(game: GridBattleGame, text: String) -> bool:
	return game.find_children("*", "Label", true, false).any(func(label: Node) -> bool: return (label as Label).text == text)

# Whether a label of `game` holds `text` among its lines.
func _tells(game: GridBattleGame, text: String) -> bool:
	return game.find_children("*", "Label", true, false).any(func(label: Node) -> bool: return (label as Label).text.split("\n").has(text))

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
