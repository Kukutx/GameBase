extends GutTest

## A grid battle in active time (`AtbBattle`): gauges that fill at each unit's
## speed, a turn of one move and one action, what an action takes or gives
## back, the end of the battle, and the same battle playing the same way.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const TacticsFixture := preload("res://gamebase/modules/tactics/test/tactics_fixture.gd")

var _started: Array[GridUnit] = []

func before_each() -> void:
	var guard := FactionData.new()
	guard.id = &"fixture_guard"
	guard.allies.assign([FactionData.PLAYER])
	var entries := TacticsFixture.entries()
	entries.append(guard)
	ContentFixture.use(self, entries)
	_started.clear()

func test_the_faster_gauge_fills_first_and_time_stands_still_while_the_player_chooses() -> void:
	var battle := _battle()
	var knight := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(0, 0))
	var raider := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(7, 5))
	battle.advance(1.9)
	assert_null(battle.get_turn_unit())
	assert_almost_eq(knight.gauge, 95.0, 0.001)
	battle.advance(0.1)
	assert_eq(battle.get_turn_unit(), knight, "speed 50 fills 100 in two seconds")
	assert_almost_eq(raider.gauge, 50.0, 0.001)
	battle.advance(5.0)
	assert_almost_eq(raider.gauge, 50.0, 0.001, "nothing fills while the knight waits for its commands")
	assert_true(battle.end_turn(knight))
	assert_eq(knight.gauge, 2.0 * AtbBattle.SKIP_BONUS, "skipping both its move and its action brings its next turn sooner")
	battle.advance(1.0)
	assert_eq(battle.get_turn_unit(), knight, "the knight fills again before the raider")
	assert_eq(_started, [knight, knight] as Array[GridUnit])

func test_with_time_flowing_while_the_player_chooses_the_foes_go_on() -> void:
	var battle := _battle()
	battle.time_flows_while_choosing = true
	var knight := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(0, 0))
	var raider := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(7, 5))
	battle.advance(4.0)
	assert_eq(battle.get_turn_unit(), knight, "the knight still waits")
	assert_eq(_started, [knight, raider] as Array[GridUnit], "the raider took its turn meanwhile")
	assert_eq(BattleGrid.distance(raider.cell, knight.cell), 12 - 3, "walking its three cells toward the knight")
	assert_eq(raider.gauge, AtbBattle.SKIP_BONUS, "it moved but did not act")

func test_units_that_fill_at_once_go_in_the_order_they_were_placed() -> void:
	var battle := _battle()
	var archer := _add(battle, &"fixture_archer", FactionData.PLAYER, Vector2i(0, 5))
	var first := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(7, 0))
	var second := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(6, 0))
	battle.advance(3.99)
	assert_eq(_started.size(), 0)
	battle.advance(0.01)
	assert_eq(_started, [archer] as Array[GridUnit], "the archer first")
	battle.advance(1.0)
	assert_eq([first.cell, second.cell], [Vector2i(7, 0), Vector2i(6, 0)], "the raiders, full too, wait while the archer chooses")
	assert_eq(first.gauge, AtbBattle.GAUGE_FULL)
	battle.end_turn(archer)
	battle.advance(0.01)
	assert_eq(_started, [archer, first, second] as Array[GridUnit], "then the raiders, as placed")
	assert_ne(first.cell, Vector2i(7, 0), "walking toward the archer")

func test_a_turn_is_one_move_and_one_action_and_ends_once_both_are_taken() -> void:
	var battle := _battle()
	var knight := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(2, 2))
	var raider := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(4, 2))
	var strike := BattleActionData.find(&"fixture_strike")
	assert_false(battle.move(knight, Vector2i(3, 2)), "not its turn")
	TacticsFixture.give_turn(battle, knight)
	var moves := battle.get_moves(knight)
	assert_true(moves.has(Vector2i(3, 2)))
	assert_false(moves.has(Vector2i(4, 2)), "no unit stops on another")
	assert_false(moves.has(Vector2i(5, 2)), "nor walks through a foe")
	assert_false(moves.has(Vector2i(2, 2)))
	assert_eq(battle.get_targets(knight, strike), [] as Array[Vector2i], "the raider is two cells away")
	assert_true(battle.move(knight, Vector2i(3, 2)))
	assert_false(battle.move(knight, Vector2i(3, 3)), "one move a turn")
	assert_eq(battle.get_targets(knight, strike), [Vector2i(4, 2)] as Array[Vector2i])
	assert_false(battle.act(knight, strike, Vector2i(3, 1)), "nothing there to strike")
	var hits := []
	battle.unit_acted.connect(func(_unit: GridUnit, _action: BattleActionData, _cell: Vector2i, unit_hits: Array[Dictionary]) -> void: hits.append_array(unit_hits))
	assert_true(battle.act(knight, strike, Vector2i(4, 2)))
	assert_eq(hits, [{"unit": raider, "amount": 6}], "power 3 and attack 4, less defense 1")
	assert_null(battle.get_turn_unit(), "moved and acted: its turn is over")
	assert_eq(knight.gauge, 0.0)
	assert_false(battle.act(knight, strike, Vector2i(4, 2)))

func test_a_unit_walks_past_its_own_side_but_never_stops_on_it() -> void:
	var battle := _battle(Vector2i(4, 1))
	var knight := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(0, 0))
	_add(battle, &"fixture_healer", FactionData.PLAYER, Vector2i(1, 0))
	_add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(3, 0))
	TacticsFixture.give_turn(battle, knight)
	assert_eq(battle.get_moves(knight), [Vector2i(2, 0)] as Array[Vector2i])
	assert_true(battle.move(knight, Vector2i(2, 0)))
	assert_true(battle.end_turn(knight))
	assert_eq(knight.gauge, AtbBattle.SKIP_BONUS, "it moved but did not act")

func test_an_area_reaches_every_foe_in_it_and_a_heal_gives_back_what_was_lost() -> void:
	var battle := _battle()
	var mage := _add(battle, &"fixture_mage", FactionData.PLAYER, Vector2i(0, 2))
	var ally := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(3, 1))
	var near := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(3, 2))
	var below := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(3, 3))
	var healer := _add(battle, &"fixture_healer", FactionData.PLAYER, Vector2i(2, 1))
	TacticsFixture.give_turn(battle, mage)
	assert_true(battle.act(mage, BattleActionData.find(&"fixture_blast"), Vector2i(3, 2)))
	assert_eq([near.health.current, below.health.current, ally.health.current], [9, 9, 20], "3 to each foe, nothing to its own side")
	battle.end_turn(mage)
	ally.health.take(2)
	TacticsFixture.give_turn(battle, healer)
	var mend := BattleActionData.find(&"fixture_mend")
	assert_eq(battle.get_targets(healer, mend), [Vector2i(2, 1), Vector2i(3, 1)] as Array[Vector2i], "itself and the knight, never a foe")
	assert_true(battle.act(healer, mend, Vector2i(3, 1)))
	assert_eq(ally.health.current, 20, "back to full, no more")

func test_the_battle_ends_won_when_the_last_foe_falls_and_lost_when_the_player_s_side_does() -> void:
	var battle := _battle()
	var knight := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(0, 0))
	var raider := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(1, 0))
	var outcome := []
	battle.ended.connect(func(won: bool) -> void: outcome.append(won))
	raider.health.set_current(6)
	TacticsFixture.give_turn(battle, knight)
	assert_true(battle.act(knight, BattleActionData.find(&"fixture_strike"), Vector2i(1, 0)))
	assert_eq(outcome, [true])
	assert_true(battle.is_over())
	assert_null(battle.get_turn_unit())
	assert_false(battle.move(knight, Vector2i(0, 1)), "nothing moves once it is over")

	var lost := _battle()
	var last := _add(lost, &"fixture_knight", FactionData.PLAYER, Vector2i(0, 0))
	var foe := _add(lost, &"fixture_raider", FactionData.MONSTERS, Vector2i(1, 0))
	last.health.set_current(4)
	TacticsFixture.give_turn(lost, foe)
	assert_true(lost.is_over())
	assert_false(lost.is_won())

	var given_up := _battle()
	_add(given_up, &"fixture_knight", FactionData.PLAYER, Vector2i(0, 0))
	_add(given_up, &"fixture_raider", FactionData.MONSTERS, Vector2i(5, 0))
	given_up.forfeit()
	assert_true(given_up.is_over())
	assert_false(given_up.is_won())

func test_allies_fight_on_their_own_and_win_with_the_player() -> void:
	var battle := _battle()
	var knight := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(0, 0))
	var guard := _add(battle, &"fixture_knight", &"fixture_guard", Vector2i(4, 4))
	var raider := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(4, 5))
	assert_true(knight.player_controlled)
	assert_false(guard.player_controlled, "the player commands their own faction only")
	raider.health.set_current(6)
	TacticsFixture.give_turn(battle, guard)
	assert_false(raider.is_alive())
	assert_true(battle.is_won())

func test_the_same_battle_plays_the_same_way() -> void:
	assert_eq(_play_out(), _play_out())
	assert_false(_play_out().is_empty())

func _play_out() -> PackedStringArray:
	# Two sides the player commands neither of.
	var battle := AtbBattle.new(BattleGrid.new(Vector2i(6, 5), [Vector2i(2, 2), Vector2i(3, 2)] as Array[Vector2i]), &"fixture_watchers")
	for cell: Vector2i in [Vector2i(0, 0), Vector2i(0, 4)]:
		battle.add_unit(BattleUnitData.find(&"fixture_knight"), &"fixture_red", cell)
	battle.add_unit(BattleUnitData.find(&"fixture_healer"), &"fixture_red", Vector2i(0, 2))
	for cell: Vector2i in [Vector2i(5, 0), Vector2i(5, 4)]:
		battle.add_unit(BattleUnitData.find(&"fixture_raider"), &"fixture_blue", cell)
	battle.add_unit(BattleUnitData.find(&"fixture_mage"), &"fixture_blue", Vector2i(5, 2))
	# An array, which the signal handlers share, unlike a packed one.
	var events: Array[String] = []
	battle.unit_moved.connect(func(unit: GridUnit, path: Array[Vector2i]) -> void: events.append("%d to %s by %d" % [unit.index, unit.cell, path.size()]))
	battle.unit_acted.connect(func(unit: GridUnit, action: BattleActionData, cell: Vector2i, hits: Array[Dictionary]) -> void:
		events.append("%d %s at %s: %s" % [unit.index, action.id, cell, hits.map(func(hit: Dictionary) -> String: return "%d %d" % [(hit["unit"] as GridUnit).index, hit["amount"]])]))
	for _frame in 1200:
		battle.advance(1.0 / 20.0)
	assert_true(battle.is_over(), "one side wins within a minute")
	return PackedStringArray(events)

func _battle(size := Vector2i(8, 6)) -> AtbBattle:
	var battle := TacticsFixture.battle(size)
	battle.turn_started.connect(func(unit: GridUnit) -> void: _started.append(unit))
	return battle

func _add(battle: AtbBattle, unit_id: StringName, faction: StringName, cell: Vector2i) -> GridUnit:
	return battle.add_unit(BattleUnitData.find(unit_id), faction, cell)
