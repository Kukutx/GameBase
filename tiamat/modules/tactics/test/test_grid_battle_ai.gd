extends GutTest

## How a unit the player does not command takes its turn (`GridBattleAi`): a
## defeat before more damage, a move only to bring a target in reach or to
## strike as hard from where fewer foes reach it, an action that recharges
## only when ready, a leader before the rest, a heal for its hurt side, a
## boost or a curse not on its units already, a goal its side takes when it
## can reach one, and a walk toward the nearest
## goal, else the nearest foe, when nothing is in reach.

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")
const TacticsFixture := preload("res://tiamat/modules/tactics/test/tactics_fixture.gd")

func before_each() -> void:
	ContentFixture.use(self, TacticsFixture.entries())

func test_a_defeat_comes_before_more_damage() -> void:
	var battle := TacticsFixture.battle()
	var raider := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(2, 2))
	var knight := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(2, 1))
	var archer := _add(battle, &"fixture_archer", FactionData.PLAYER, Vector2i(3, 2))
	archer.health.set_current(6)
	assert_eq(battle.ai.best_plan(battle, raider)["target"], Vector2i(3, 2))
	TacticsFixture.give_turn(battle, raider)
	assert_false(archer.is_alive(), "6 defeats the archer; the knight would only lose 4")
	assert_eq(knight.health.current, 20)
	assert_eq(raider.cell, Vector2i(2, 2), "no need to move")

func test_it_moves_to_bring_a_foe_in_reach_then_strikes() -> void:
	var battle := TacticsFixture.battle()
	var raider := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(0, 0))
	var knight := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(3, 0))
	TacticsFixture.give_turn(battle, raider)
	assert_eq(raider.cell, Vector2i(2, 0))
	assert_eq(knight.health.current, 16)

func test_for_the_same_good_it_strikes_from_where_fewer_foes_reach_it() -> void:
	var battle := TacticsFixture.battle(Vector2i(8, 1))
	var archer := _add(battle, &"fixture_archer", FactionData.MONSTERS, Vector2i(4, 0))
	var left := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(0, 0))
	var right := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(7, 0))
	var threats := battle.get_threats(FactionData.MONSTERS, archer)
	assert_eq([threats.get(Vector2i(4, 0)), threats.get(Vector2i(2, 0)), threats.get(Vector2i(5, 0))], [2, 1, 1], "both knights reach the middle")
	TacticsFixture.give_turn(battle, archer)
	assert_eq(archer.cell, Vector2i(2, 0), "it shoots as hard from where only one knight reaches it, the first such cell")
	assert_eq([left.health.current, right.health.current], [17, 20])

func test_for_the_same_good_and_the_same_foes_it_strikes_from_cover() -> void:
	var results: Array = []
	for cover: Array[Vector2i] in [[] as Array[Vector2i], [Vector2i(3, 0)] as Array[Vector2i]]:
		var battle := AtbBattle.new(BattleGrid.new(Vector2i(8, 1), [] as Array[Vector2i], cover, 0.3), FactionData.PLAYER)
		var archer := _add(battle, &"fixture_archer", FactionData.MONSTERS, Vector2i(4, 0))
		var knight := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(0, 0))
		var threats := battle.get_threats(FactionData.MONSTERS, archer)
		assert_eq([threats.get(Vector2i(2, 0)), threats.get(Vector2i(3, 0))], [1, 1], "the knight reaches both")
		TacticsFixture.give_turn(battle, archer)
		results.append([archer.cell, knight.health.current])
	assert_eq(results, [[Vector2i(2, 0), 17], [Vector2i(3, 0), 17]], "in the open the first such cell, else the one in cover")

func test_it_looses_an_action_that_recharges_when_ready_and_strikes_meanwhile() -> void:
	var battle := TacticsFixture.battle()
	var captain := _add(battle, &"fixture_captain", FactionData.MONSTERS, Vector2i(1, 2))
	_add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(3, 2))
	_add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(3, 3))
	var used: Array[StringName] = []
	battle.unit_acted.connect(func(_unit: GridUnit, action: BattleActionData, _cell: Vector2i, _hits: Array[Dictionary]) -> void: used.append(action.id))
	for _turn in 4:
		TacticsFixture.give_turn(battle, captain)
	assert_eq(used, [&"fixture_volley", &"fixture_strike", &"fixture_strike", &"fixture_volley"], "the volley over both knights, then strikes for two turns while it recharges")

func test_it_boosts_its_side_and_curses_a_foe_once_then_strikes_while_they_hold() -> void:
	var battle := TacticsFixture.battle()
	var herald := _add(battle, &"fixture_herald", FactionData.MONSTERS, Vector2i(0, 0))
	_add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(1, 0))
	var knight := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(0, 1))
	var rally := BattleActionData.find(&"fixture_rally")
	assert_eq(battle.ai.score(battle, herald, rally, herald.cell, herald.cell), 2 * 2 * GridBattleAi.BOOST_SCORE * 2, "2 attack through two turns, on the herald and the raider")
	var used: Array[StringName] = []
	battle.unit_acted.connect(func(_unit: GridUnit, action: BattleActionData, _cell: Vector2i, _hits: Array[Dictionary]) -> void: used.append(action.id))
	for _turn in 4:
		TacticsFixture.give_turn(battle, herald)
	assert_eq(used, [&"fixture_rally", &"fixture_hex", &"fixture_strike", &"fixture_strike"], "the rally, worth 8; the hex, 3 and 6 for the curse; then strikes worth more than either again")
	assert_eq(knight.health.current, 20 - 3 - 7 - 5)

func test_a_leader_s_fall_is_worth_its_whole_side() -> void:
	var battle := TacticsFixture.battle()
	var raider := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(2, 2))
	var knight := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(2, 1))
	var captain := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(3, 2))
	_add(battle, &"fixture_archer", FactionData.PLAYER, Vector2i(7, 5))
	knight.health.set_current(4)
	captain.health.set_current(4)
	captain.leader = true
	var strike := BattleActionData.find(&"fixture_strike")
	assert_eq(battle.ai.score(battle, raider, strike, Vector2i(3, 2), raider.cell), 4 + GridBattleAi.DEFEAT_SCORE * 3, "the captain and the two who would flee")
	assert_eq(battle.ai.score(battle, raider, strike, Vector2i(2, 1), raider.cell), 4 + GridBattleAi.DEFEAT_SCORE)
	TacticsFixture.give_turn(battle, raider)
	assert_false(captain.is_alive(), "it fells the leader")
	assert_true(battle.is_over())

func test_a_healer_mends_its_hurt_side() -> void:
	var battle := TacticsFixture.battle()
	var healer := _add(battle, &"fixture_healer", FactionData.MONSTERS, Vector2i(0, 0))
	var raider := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(1, 0))
	_add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(7, 5))
	raider.health.set_current(4)
	TacticsFixture.give_turn(battle, healer)
	assert_eq(raider.health.current, 9)

func test_with_nothing_in_reach_it_walks_toward_the_nearest_foe_or_stays_when_none_can_be_reached() -> void:
	var battle := TacticsFixture.battle()
	var raider := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(0, 0))
	_add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(7, 5))
	var near := _add(battle, &"fixture_archer", FactionData.PLAYER, Vector2i(0, 5))
	assert_true(battle.ai.best_plan(battle, raider).is_empty())
	TacticsFixture.give_turn(battle, raider)
	assert_eq(raider.cell, Vector2i(0, 3), "three cells toward the archer, five away, not the knight, twelve away")
	assert_eq(BattleGrid.distance(raider.cell, near.cell), 2)

	# A wall of water between them.
	var walled := TacticsFixture.battle(Vector2i(5, 3), [Vector2i(2, 0), Vector2i(2, 1), Vector2i(2, 2)] as Array[Vector2i])
	var stuck := _add(walled, &"fixture_raider", FactionData.MONSTERS, Vector2i(0, 1))
	_add(walled, &"fixture_knight", FactionData.PLAYER, Vector2i(4, 1))
	TacticsFixture.give_turn(walled, stuck)
	assert_eq(stuck.cell, Vector2i(0, 1))

func test_it_takes_a_goal_in_reach_striking_from_there_and_else_walks_toward_one() -> void:
	var battle := TacticsFixture.battle()
	battle.goal_cells[Vector2i(3, 2)] = true
	battle.goal_faction = FactionData.MONSTERS
	var raider := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(0, 2))
	var knight := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(3, 3))
	var archer := _add(battle, &"fixture_archer", FactionData.PLAYER, Vector2i(0, 3))
	archer.health.set_current(2)
	assert_eq(battle.ai.goal_in_reach(battle, raider), [Vector2i(3, 2)] as Array[Vector2i])
	TacticsFixture.give_turn(battle, raider)
	assert_eq(raider.cell, Vector2i(3, 2), "the goal before the archer it could defeat")
	assert_eq(knight.health.current, 16, "striking the knight beside it from there")
	assert_true(battle.is_over() and not battle.is_won())

	var far := TacticsFixture.battle()
	far.goal_cells[Vector2i(7, 0)] = true
	far.goal_faction = FactionData.MONSTERS
	var runner := _add(far, &"fixture_raider", FactionData.MONSTERS, Vector2i(2, 0))
	_add(far, &"fixture_knight", FactionData.PLAYER, Vector2i(0, 5))
	TacticsFixture.give_turn(far, runner)
	assert_eq(runner.cell, Vector2i(5, 0), "three cells toward the goal, not the knight")
	assert_false(far.is_over())

func _add(battle: AtbBattle, unit_id: StringName, faction: StringName, cell: Vector2i) -> GridUnit:
	return battle.add_unit(BattleUnitData.find(unit_id), faction, cell)
