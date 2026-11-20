extends GutTest

## A grid battle in active time (`AtbBattle`): gauges that fill at each unit's
## speed, a turn of one move and one action, what an action takes or gives
## back and the boosts it puts on, units that arrive while it runs, the end of
## the battle, and the same battle playing the same way.

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")
const TacticsFixture := preload("res://tiamat/modules/tactics/test/tactics_fixture.gd")

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

func test_the_turns_to_come_follow_the_gauges() -> void:
	var battle := _battle()
	var knight := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(0, 0))
	var raider := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(7, 5))
	assert_eq(battle.get_turn_order(4), [knight, knight, raider, knight] as Array[GridUnit],
		"speed 50 fills twice while speed 25 fills once, and the first placed goes first on a tie")
	battle.advance(2.0)
	assert_eq(battle.get_turn_unit(), knight)
	assert_eq(battle.get_turn_order(3), [knight, raider, knight] as Array[GridUnit], "after the knight's turn now, as though it moved and acted")
	for _turn in 2:
		# As though it moved and acted.
		knight.has_moved = true
		knight.has_acted = true
		assert_true(battle.end_turn(knight))
		battle.advance(2.0)
	assert_eq(_started, [knight, knight, raider, knight] as Array[GridUnit], "the turns came as told")
	raider.health.take(raider.health.maximum)
	assert_eq(battle.get_turn_order(2), [knight, knight] as Array[GridUnit], "a fallen unit takes no more turns")

func test_the_player_takes_a_move_back_until_the_unit_acts() -> void:
	var battle := _battle()
	var knight := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(2, 2))
	_add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(5, 2))
	var strike := BattleActionData.find(&"fixture_strike")
	TacticsFixture.give_turn(battle, knight)
	assert_false(battle.can_undo_move(knight), "nothing to take back before it moves")
	var undone: Array[GridUnit] = []
	battle.move_undone.connect(func(unit: GridUnit) -> void: undone.append(unit))
	assert_true(battle.move(knight, Vector2i(3, 2)))
	assert_true(battle.can_undo_move(knight))
	assert_true(battle.undo_move(knight))
	assert_eq(knight.cell, Vector2i(2, 2), "back where its turn found it")
	assert_false(knight.has_moved, "free to move again")
	assert_eq(undone, [knight] as Array[GridUnit])
	assert_false(battle.undo_move(knight), "nothing more to take back")
	assert_true(battle.move(knight, Vector2i(4, 2)))
	assert_true(battle.act(knight, strike, Vector2i(5, 2)))
	assert_false(battle.undo_move(knight), "acted: the move stands")
	assert_eq(knight.cell, Vector2i(4, 2))

func test_a_foe_s_turn_or_a_unit_in_the_way_fixes_the_move() -> void:
	var battle := _battle()
	battle.time_flows_while_choosing = true
	var knight := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(0, 0))
	_add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(7, 5))
	TacticsFixture.give_turn(battle, knight)
	assert_true(battle.move(knight, Vector2i(1, 0)))
	battle.advance(3.9)
	assert_true(battle.can_undo_move(knight), "the raider has not taken its turn yet")
	battle.advance(0.2)
	assert_false(battle.can_undo_move(knight), "it took one meanwhile")
	assert_false(battle.undo_move(knight))
	var other := _battle()
	var archer := _add(other, &"fixture_archer", FactionData.PLAYER, Vector2i(0, 0))
	var healer := _add(other, &"fixture_healer", FactionData.PLAYER, Vector2i(3, 3))
	_add(other, &"fixture_raider", FactionData.MONSTERS, Vector2i(7, 5))
	TacticsFixture.give_turn(other, archer)
	assert_true(other.move(archer, Vector2i(1, 0)))
	healer.cell = Vector2i(0, 0)
	assert_false(other.can_undo_move(archer), "someone stands where it came from")

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

func test_the_danger_is_where_the_foes_could_strike_next() -> void:
	var battle := _battle(Vector2i(8, 1))
	_add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(0, 0))
	_add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(7, 0))
	_add(battle, &"fixture_archer", &"fixture_guard", Vector2i(1, 0))
	assert_eq(_columns(battle.get_danger()), [3, 4, 5, 6, 7], "the raider walks three and strikes one away; the guard is no foe")
	var healer := _add(battle, &"fixture_healer", FactionData.PLAYER, Vector2i(5, 0))
	assert_eq(_columns(battle.get_danger()), [5, 6, 7], "no foe walks past the player's side")
	assert_eq(_columns(battle.get_danger(healer)), [3, 4, 5, 6, 7], "the unit choosing where to go leaves its cell")
	var open := TacticsFixture.battle(Vector2i(11, 11), [Vector2i(5, 9)] as Array[Vector2i])
	_add(open, &"fixture_mage", FactionData.MONSTERS, Vector2i(5, 5))
	var danger := open.get_danger()
	assert_true(danger.has(Vector2i(0, 4)), "the mage walks two, blasts three away and the blast reaches one more")
	assert_false(danger.has(Vector2i(0, 3)), "seven away is out of its reach")
	assert_false(danger.has(Vector2i(5, 9)), "a blocked cell holds no one to strike")

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

func test_an_action_tells_what_it_would_do_before_it_does() -> void:
	var battle := _battle()
	var mage := _add(battle, &"fixture_mage", FactionData.PLAYER, Vector2i(0, 2))
	var ally := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(3, 1))
	var near := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(3, 2))
	var below := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(3, 3))
	var healer := _add(battle, &"fixture_healer", FactionData.PLAYER, Vector2i(2, 1))
	below.health.set_current(2)
	TacticsFixture.give_turn(battle, mage)
	var blast := BattleActionData.find(&"fixture_blast")
	assert_eq(battle.forecast(mage, blast, Vector2i(3, 2)), [
		{"unit": near, "amount": 3, "defeats": false},
		{"unit": below, "amount": 2, "defeats": true},
	] as Array[Dictionary], "each foe in the area, no more than it has; nothing to its own side")
	assert_eq(near.health.current, 12, "told, not done")
	assert_true(battle.act(mage, blast, Vector2i(3, 2)))
	assert_eq([near.health.current, below.is_alive()], [9, false], "as told")
	battle.end_turn(mage)
	ally.health.take(2)
	TacticsFixture.give_turn(battle, healer)
	assert_eq(battle.forecast(healer, BattleActionData.find(&"fixture_mend"), Vector2i(3, 1)), [{"unit": ally, "amount": 2, "defeats": false}] as Array[Dictionary], "no more than it lost")

func test_a_unit_in_cover_takes_less_damage_as_told() -> void:
	var battle := AtbBattle.new(BattleGrid.new(Vector2i(8, 6), [] as Array[Vector2i], [Vector2i(3, 2)] as Array[Vector2i], 0.5), FactionData.PLAYER)
	var knight := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(2, 2))
	var covered := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(3, 2))
	var open := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(2, 3))
	TacticsFixture.give_turn(battle, knight)
	var strike := BattleActionData.find(&"fixture_strike")
	assert_eq(battle.amount_of(knight, strike, open), 6, "all of it in the open")
	assert_eq(battle.amount_of(knight, strike, covered), 3, "half of it in cover")
	assert_eq(battle.forecast(knight, strike, Vector2i(3, 2)), [{"unit": covered, "amount": 3, "defeats": false}] as Array[Dictionary])
	assert_true(battle.act(knight, strike, Vector2i(3, 2)))
	assert_eq(covered.health.current, 9, "as told")

func test_an_action_that_recharges_waits_its_user_s_turns() -> void:
	var battle := _battle()
	var captain := _add(battle, &"fixture_captain", FactionData.PLAYER, Vector2i(0, 2))
	_add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(3, 2))
	var volley := BattleActionData.find(&"fixture_volley")
	TacticsFixture.give_turn(battle, captain)
	assert_true(captain.is_ready(volley))
	assert_true(battle.act(captain, volley, Vector2i(3, 2)))
	battle.end_turn(captain)
	var waits: Array[int] = []
	for turn in 3:
		TacticsFixture.give_turn(battle, captain)
		waits.append(captain.turns_to_ready(volley))
		assert_eq(battle.get_targets(captain, volley).is_empty(), turn < 2, "no aim while it recharges")
		battle.end_turn(captain)
	assert_eq(waits, [2, 1, 0], "two of its turns go by, then it looses it again")
	assert_true(captain.is_ready(BattleActionData.find(&"fixture_strike")), "an action that never recharges is always ready")

func test_a_foe_s_action_that_recharges_past_its_next_turn_is_no_danger() -> void:
	var battle := _battle(Vector2i(8, 1))
	_add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(0, 0))
	var captain := _add(battle, &"fixture_captain", FactionData.MONSTERS, Vector2i(7, 0))
	assert_eq(_columns(battle.get_danger()), [1, 2, 3, 4, 5, 6, 7], "it walks two and its volley reaches three and one more")
	captain.start_turn()
	captain.use(BattleActionData.find(&"fixture_volley"))
	assert_eq(_columns(battle.get_danger()), [4, 5, 6, 7], "only its strike while the volley recharges")
	captain.start_turn()
	assert_eq(_columns(battle.get_danger()), [4, 5, 6, 7])
	captain.start_turn()
	assert_eq(_columns(battle.get_danger()), [1, 2, 3, 4, 5, 6, 7], "ready on its next turn")

func test_a_delay_sets_a_foe_s_turn_back_unless_it_falls() -> void:
	var battle := _battle()
	var shield := _add(battle, &"fixture_shield", FactionData.PLAYER, Vector2i(1, 1))
	var raider := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(2, 1))
	var dying := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(1, 2))
	var slow := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(0, 1))
	raider.gauge = 80.0
	dying.gauge = 80.0
	dying.health.set_current(1)
	slow.gauge = 20.0
	TacticsFixture.give_turn(battle, shield)
	var bash := BattleActionData.find(&"fixture_bash")
	assert_eq(battle.forecast(shield, bash, Vector2i(2, 1)), [{"unit": raider, "amount": 2, "defeats": false, "delay": 50.0}] as Array[Dictionary], "told before it does")
	assert_eq(battle.forecast(shield, bash, Vector2i(1, 2))[0]["delay"], 0.0, "no delay for a foe it fells")
	assert_eq(battle.delay_of(bash, slow), 20.0, "no further back than empty")
	assert_eq(battle.delay_of(bash, shield), 0.0, "never the unit taking its turn")
	assert_eq(battle.delay_of(BattleActionData.find(&"fixture_strike"), raider), 0.0, "an action that does not delay")
	var hits: Array[Dictionary] = []
	battle.unit_acted.connect(func(_unit: GridUnit, _action: BattleActionData, _cell: Vector2i, done: Array[Dictionary]) -> void: hits.assign(done))
	assert_true(battle.act(shield, bash, Vector2i(2, 1)))
	assert_eq(raider.gauge, 30.0, "half a turn back")
	assert_eq(hits, [{"unit": raider, "amount": 2, "delay": 50.0}] as Array[Dictionary])

func test_a_foe_s_delay_takes_the_turn_a_player_s_unit_waited_for() -> void:
	var battle := _battle()
	var healer := _add(battle, &"fixture_healer", FactionData.PLAYER, Vector2i(5, 5))
	var knight := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(1, 1))
	var shield := _add(battle, &"fixture_shield", FactionData.MONSTERS, Vector2i(2, 1))
	TacticsFixture.give_turn(battle, healer)
	TacticsFixture.give_turn(battle, knight)
	assert_eq(battle.get_turn_order(1), [knight] as Array[GridUnit], "the knight waits, full, for the healer's turn to end")
	TacticsFixture.give_turn(battle, shield)
	assert_eq(knight.gauge, 50.0, "the shield bashes it, as worth more than its strike")
	battle.end_turn(healer)
	assert_null(battle.get_turn_unit(), "the knight's turn comes later")

func test_a_unit_delayed_by_one_that_filled_with_it_waits_for_its_gauge() -> void:
	var battle := AtbBattle.new(BattleGrid.new(Vector2i(4, 1)), &"fixture_watchers")
	var shield := battle.add_unit(BattleUnitData.find(&"fixture_shield"), &"fixture_red", Vector2i(0, 0))
	var raider := battle.add_unit(BattleUnitData.find(&"fixture_raider"), &"fixture_blue", Vector2i(1, 0))
	var started: Array[GridUnit] = []
	battle.turn_started.connect(func(unit: GridUnit) -> void: started.append(unit))
	battle.advance(4.0)
	assert_eq(started, [shield] as Array[GridUnit], "both fill at once, and the shield, placed first, bashes the raider")
	assert_eq(raider.gauge, 50.0)
	battle.advance(2.0)
	assert_eq(started, [shield, raider] as Array[GridUnit], "which fills again two seconds on")

func test_a_boost_changes_what_actions_do_through_the_unit_s_next_turns() -> void:
	var battle := _battle()
	var herald := _add(battle, &"fixture_herald", FactionData.PLAYER, Vector2i(1, 1))
	var knight := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(1, 2))
	_add(battle, &"fixture_archer", FactionData.PLAYER, Vector2i(5, 5))
	var raider := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(2, 1))
	TacticsFixture.give_turn(battle, herald)
	var rally := BattleActionData.find(&"fixture_rally")
	var strike := BattleActionData.find(&"fixture_strike")
	assert_eq(battle.forecast(herald, rally, herald.cell), [
		{"unit": herald, "amount": 0, "defeats": false, "boosts": rally.boosts},
		{"unit": knight, "amount": 0, "defeats": false, "boosts": rally.boosts},
	] as Array[Dictionary], "told before it does: its side around it, neither the archer afar nor the raider")
	assert_eq(battle.amount_of(knight, strike, raider), 6, "3 and the knight's 4, less the raider's 1")
	var hits: Array[Dictionary] = []
	battle.unit_acted.connect(func(_unit: GridUnit, _action: BattleActionData, _cell: Vector2i, done: Array[Dictionary]) -> void: hits.assign(done))
	assert_true(battle.act(herald, rally, herald.cell))
	assert_eq(hits, [{"unit": herald, "amount": 0, "boosts": rally.boosts}, {"unit": knight, "amount": 0, "boosts": rally.boosts}] as Array[Dictionary])
	assert_eq([herald.get_attack(), knight.get_attack(), raider.get_attack()], [4, 6, 3], "2 more attack on its side alone")
	assert_eq(battle.amount_of(knight, strike, raider), 8)
	assert_eq([herald.get_boost_turns(), knight.get_boost_turns()], [2, 2], "through each one's next two turns")
	knight.start_turn()
	knight.start_turn()
	assert_eq(knight.get_attack(), 6, "on its second turn still")
	knight.start_turn()
	assert_eq([knight.get_attack(), knight.get_boost_turns(), knight.has_boost(rally)], [4, 0, false], "gone by its third")
	knight.boost(rally)
	knight.boost(rally)
	assert_eq(knight.get_attack(), 6, "the same boost again starts over rather than adds up")

func test_a_curse_lowers_the_defense_of_a_foe_it_leaves_standing() -> void:
	var battle := _battle()
	var herald := _add(battle, &"fixture_herald", FactionData.PLAYER, Vector2i(1, 1))
	var raider := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(2, 1))
	var dying := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(1, 2))
	dying.health.set_current(1)
	TacticsFixture.give_turn(battle, herald)
	var hex := BattleActionData.find(&"fixture_hex")
	assert_eq(battle.forecast(herald, hex, Vector2i(2, 1)), [{"unit": raider, "amount": 2, "defeats": false, "boosts": hex.boosts}] as Array[Dictionary], "told before it does")
	assert_false(battle.forecast(herald, hex, Vector2i(1, 2))[0].has("boosts"), "no curse on a foe it fells")
	var hits: Array[Dictionary] = []
	battle.unit_acted.connect(func(_unit: GridUnit, _action: BattleActionData, _cell: Vector2i, done: Array[Dictionary]) -> void: hits.assign(done))
	assert_true(battle.act(herald, hex, Vector2i(2, 1)))
	assert_eq(hits, [{"unit": raider, "amount": 2, "boosts": hex.boosts}] as Array[Dictionary])
	assert_eq([raider.get_defense(), raider.get_boost_turns()], [-1, 3], "2 less defense through its next three turns")
	assert_eq(battle.amount_of(herald, BattleActionData.find(&"fixture_strike"), raider), 6, "3 and the herald's 2, less the raider's -1")

func test_a_leader_s_fall_sends_the_rest_of_its_side_fleeing() -> void:
	var battle := _battle()
	var knight := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(1, 1))
	var chief := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(2, 1))
	var follower := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(6, 4))
	chief.leader = true
	chief.health.set_current(6)
	var fled: Array[GridUnit] = []
	var defeated: Array[GridUnit] = []
	battle.unit_fled.connect(func(unit: GridUnit) -> void: fled.append(unit))
	battle.unit_defeated.connect(func(unit: GridUnit) -> void: defeated.append(unit))
	TacticsFixture.give_turn(battle, knight)
	assert_true(battle.act(knight, BattleActionData.find(&"fixture_strike"), Vector2i(2, 1)))
	assert_eq(defeated, [chief] as Array[GridUnit])
	assert_eq(fled, [follower] as Array[GridUnit], "the rest of its side flees")
	assert_true(follower.fled and not follower.is_alive() and not follower.health.is_depleted(), "gone, not defeated")
	assert_null(battle.get_unit_at(Vector2i(6, 4)))
	assert_true(battle.is_over() and battle.is_won())

	var lost := _battle()
	var captain := _add(lost, &"fixture_knight", FactionData.PLAYER, Vector2i(0, 0))
	var soldier := _add(lost, &"fixture_archer", FactionData.PLAYER, Vector2i(7, 5))
	var guard := _add(lost, &"fixture_knight", &"fixture_guard", Vector2i(3, 1))
	var raider := _add(lost, &"fixture_raider", FactionData.MONSTERS, Vector2i(1, 0))
	captain.leader = true
	captain.health.set_current(4)
	TacticsFixture.give_turn(lost, raider)
	assert_true(soldier.fled, "the player's side flees with its leader")
	assert_false(guard.fled, "an ally of another faction stands")
	assert_false(lost.is_over(), "and fights on")
	raider.health.set_current(1)
	TacticsFixture.give_turn(lost, guard)
	assert_true(lost.is_over())
	assert_true(lost.is_won(), "won with the ally left")

func test_a_unit_of_the_side_that_takes_a_goal_wins_by_ending_its_turn_there() -> void:
	var battle := _battle()
	battle.goal_cells[Vector2i(4, 0)] = true
	battle.goal_cells[Vector2i(3, 2)] = true
	var knight := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(3, 0))
	var guard := _add(battle, &"fixture_archer", &"fixture_guard", Vector2i(7, 5))
	var raider := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(4, 0))
	assert_true(battle.takes_goals(knight) and battle.takes_goals(guard), "the player's side takes the goals at first")
	assert_false(battle.takes_goals(raider))
	var taken: Array[GridUnit] = []
	battle.goal_taken.connect(func(unit: GridUnit) -> void: taken.append(unit))
	TacticsFixture.give_turn(battle, raider)
	assert_eq(raider.cell, Vector2i(4, 0))
	assert_eq(knight.health.current, 16, "the raider struck from a goal")
	assert_false(battle.is_over(), "a foe that ends its turn on one takes nothing")
	TacticsFixture.give_turn(battle, knight)
	assert_true(battle.move(knight, Vector2i(3, 2)))
	assert_false(battle.is_over(), "not until its turn ends")
	assert_true(battle.can_undo_move(knight), "the move may still be taken back")
	assert_true(battle.end_turn(knight))
	assert_eq(taken, [knight] as Array[GridUnit])
	assert_true(battle.is_over() and battle.is_won(), "won with a foe standing")

	var lost := _battle()
	lost.goal_cells[Vector2i(0, 0)] = true
	lost.goal_faction = FactionData.MONSTERS
	_add(lost, &"fixture_archer", FactionData.PLAYER, Vector2i(7, 5))
	var runner := _add(lost, &"fixture_raider", FactionData.MONSTERS, Vector2i(2, 0))
	TacticsFixture.give_turn(lost, runner)
	assert_eq(runner.cell, Vector2i(0, 0), "the foe steps onto the goal it takes")
	assert_true(lost.is_over() and not lost.is_won(), "and the battle is lost")

func test_units_on_their_way_arrive_once_their_battle_time_comes() -> void:
	var battle := _battle()
	var arrived: Array[GridUnit] = []
	battle.unit_arrived.connect(func(unit: GridUnit) -> void: arrived.append(unit))
	var knight := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(0, 0))
	_add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(1, 0))
	battle.add_arrival(BattleUnitData.find(&"fixture_raider"), FactionData.MONSTERS, Vector2i(7, 5), 3.0, true)
	battle.add_arrival(BattleUnitData.find(&"fixture_archer"), FactionData.PLAYER, Vector2i(0, 0), 1.0)
	assert_eq(battle.arrivals.size(), 2)
	assert_eq(battle.arrivals.get_next(), 1.0, "the soonest first")
	assert_eq(battle.units.size(), 2, "on their way, not on the grid")
	battle.advance(1.0)
	assert_eq(arrived.size(), 1)
	assert_eq(arrived[0].cell, Vector2i(0, 1), "in the open cell nearest its own, where the knight stands")
	assert_eq(arrived[0].gauge, 0.0, "its gauge empty")
	assert_true(arrived[0].player_controlled)
	assert_almost_eq(knight.gauge, 50.0, 0.001)
	battle.advance(5.0)
	assert_eq(battle.get_turn_unit(), knight)
	assert_almost_eq(battle.time, 2.0, 0.001, "battle time stands still while the player chooses")
	assert_eq(battle.arrivals.size(), 1, "and the next stays on its way")
	assert_true(battle.end_turn(knight))
	battle.advance(1.0)
	assert_eq(arrived.size(), 2)
	assert_eq(arrived[1].cell, Vector2i(7, 5))
	assert_true(arrived[1].leader, "it leads its side")
	assert_eq(battle.arrivals.get_next(), INF)
	battle.add_arrival(BattleUnitData.find(&"fixture_archer"), FactionData.PLAYER, Vector2i(3, 3), 1.0)
	assert_eq(battle.units.size(), 5, "one already due is placed at once")

func test_units_on_their_way_keep_the_battle_going_unless_their_leader_fell() -> void:
	var battle := _battle()
	var knight := _add(battle, &"fixture_knight", FactionData.PLAYER, Vector2i(0, 0))
	var raider := _add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2i(1, 0))
	raider.health.set_current(1)
	battle.add_arrival(BattleUnitData.find(&"fixture_raider"), FactionData.MONSTERS, Vector2i(7, 5), 30.0)
	TacticsFixture.give_turn(battle, knight)
	assert_true(battle.act(knight, BattleActionData.find(&"fixture_strike"), Vector2i(1, 0)))
	assert_false(raider.is_alive())
	assert_false(battle.is_over(), "a foe on its way fights on")

	var held := _battle()
	var last := _add(held, &"fixture_knight", FactionData.PLAYER, Vector2i(0, 0))
	var foe := _add(held, &"fixture_raider", FactionData.MONSTERS, Vector2i(1, 0))
	last.health.set_current(4)
	held.add_arrival(BattleUnitData.find(&"fixture_archer"), FactionData.PLAYER, Vector2i(7, 5), 30.0)
	TacticsFixture.give_turn(held, foe)
	assert_false(last.is_alive())
	assert_false(held.is_over(), "so does the player's")

	var routed := _battle()
	var hero := _add(routed, &"fixture_knight", FactionData.PLAYER, Vector2i(0, 0))
	var chief := _add(routed, &"fixture_raider", FactionData.MONSTERS, Vector2i(1, 0))
	chief.leader = true
	chief.health.set_current(1)
	routed.add_arrival(BattleUnitData.find(&"fixture_raider"), FactionData.MONSTERS, Vector2i(7, 5), 30.0)
	TacticsFixture.give_turn(routed, hero)
	assert_true(routed.act(hero, BattleActionData.find(&"fixture_strike"), Vector2i(1, 0)))
	assert_eq(routed.arrivals.size(), 0, "its side's units on their way turn back with it")
	assert_true(routed.is_over() and routed.is_won())

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

# The columns of `cells` on a grid one row high, left to right.
func _columns(cells: Dictionary[Vector2i, bool]) -> Array:
	var columns := cells.keys().map(func(cell: Vector2i) -> int: return cell.x)
	columns.sort()
	return columns
