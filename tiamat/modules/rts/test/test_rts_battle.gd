extends GutTest

## A command battle in real time (`RtsBattle`): a group sent somewhere goes
## each to its own place, around obstacles and never into one; blows take the
## damage less the armor once a cooldown; units with nothing to do go after
## the foes they see; a holding unit fights only what it reaches; a move
## passes foes by while an attack-move fights them and goes on; an attack
## order follows its foe anywhere; the others advance when the battle says so,
## on the ground to hold when there is one; the side that takes that ground
## wins once it stood there with no foe long enough; the same orders play the same battle; and it ends won, or
## given up.

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")
const RtsFixture := preload("res://tiamat/modules/rts/test/rts_fixture.gd")

var _ended: Array[bool] = []

func before_each() -> void:
	_ended.clear()
	ContentFixture.use(self, RtsFixture.entries())

func test_sides_join_as_they_come_and_fight_the_factions_hostile_to_theirs() -> void:
	var sides := RtsSides.new()
	assert_eq(sides.side_of(FactionData.PLAYER), 0)
	assert_eq(sides.side_of(FactionData.MONSTERS), 1, "a new faction joins as the next side")
	assert_eq(sides.side_of(FactionData.PLAYER), 0, "and keeps its side")
	assert_eq(sides.count(), 2)
	assert_true(sides.are_hostile(0, 1))
	assert_false(sides.are_hostile(0, 0), "a side never fights itself")
	assert_eq(sides.foes_of(0), PackedInt32Array([1]))
	assert_eq(sides.every(), PackedInt32Array([0, 1]))
	assert_eq(sides.friends_of(1), PackedInt32Array([1]), "and fights beside its own")

func test_a_healer_mends_the_most_hurt_friend_it_sees_and_never_strikes() -> void:
	var battle := RtsFixture.battle()
	var medic := RtsFixture.add(battle, &"fixture_medic", FactionData.PLAYER, Vector2(100.0, 80.0))
	var scratched := RtsFixture.add(battle, &"fixture_footman", FactionData.PLAYER, Vector2(130.0, 80.0))
	var wounded := RtsFixture.add(battle, &"fixture_footman", FactionData.PLAYER, Vector2(100.0, 120.0))
	# A foe out of everyone's sight, so the battle goes on.
	RtsFixture.add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2(300.0, 20.0))
	scratched.health.take(4)
	wounded.health.take(12)
	var mended: Array[String] = []
	battle.unit_healed.connect(func(healer: RtsUnit, target: RtsUnit, amount: int) -> void:
		mended.append("%s %d" % ["wounded" if target == wounded else "scratched", amount]))
	var struck: Array[RtsUnit] = []
	battle.unit_attacked.connect(func(attacker: RtsUnit, _target: RtsUnit, _amount: int) -> void: struck.append(attacker))
	assert_eq(battle.get_most_hurt_friend(medic), wounded)
	assert_true(RtsFixture.run_until(battle, func() -> bool: return mended.size() >= 4, 10.0))
	assert_eq(mended, ["wounded 4", "wounded 4", "wounded 4", "scratched 4"] as Array[String], "the most hurt first, then the next")
	assert_eq(struck, [] as Array[RtsUnit], "it never strikes")
	assert_eq(wounded.health.current, wounded.health.maximum)
	assert_null(battle.get_most_hurt_friend(medic), "none left to mend")

func test_healers_follow_an_attack_and_alone_hold_nothing() -> void:
	var battle := RtsFixture.battle()
	battle.ended.connect(_on_ended)
	var footman := RtsFixture.add(battle, &"fixture_footman", FactionData.PLAYER, Vector2(240.0, 120.0))
	var medic := RtsFixture.add(battle, &"fixture_medic", FactionData.PLAYER, Vector2(20.0, 20.0))
	var brute := RtsFixture.add(battle, &"fixture_brute", FactionData.MONSTERS, Vector2(254.0, 120.0))
	battle.order_attack([footman, medic] as Array[RtsUnit], brute)
	assert_eq(footman.order, RtsUnit.Order.ATTACK)
	assert_eq(medic.order, RtsUnit.Order.ATTACK_MOVE, "a healer attack-moves to the foe, mending on the way")
	battle.order_hold([medic] as Array[RtsUnit])
	assert_true(RtsFixture.run_until(battle, battle.is_over, 30.0))
	assert_false(footman.is_alive())
	assert_true(medic.is_alive(), "the medic still stands")
	assert_false(battle.is_won(), "but a side of healers alone has lost")
	assert_eq(_ended, [false] as Array[bool])

func test_a_group_sent_somewhere_goes_each_to_its_own_place() -> void:
	var battle := RtsFixture.battle()
	var group: Array[RtsUnit] = []
	for index in 4:
		group.append(RtsFixture.add(battle, &"fixture_footman", FactionData.PLAYER, Vector2(20.0, 20.0 + index * 12.0)))
	var goal := Vector2(200.0, 80.0)
	battle.order_move(group, goal)
	assert_true(RtsFixture.run_until(battle, func() -> bool: return group.all(func(unit: RtsUnit) -> bool: return unit.order == RtsUnit.Order.IDLE), 15.0), "all of them get there")
	for unit: RtsUnit in group:
		assert_lt(unit.position.distance_to(goal), 20.0)
		for other: RtsUnit in group:
			if other != unit:
				assert_gte(unit.position.distance_to(other.position), 9.9, "no two overlap, but for rounding")

func test_a_unit_walks_around_an_obstacle_and_never_into_it() -> void:
	var battle := RtsFixture.battle(Vector2(320.0, 160.0), [Rect2(150.0, 0.0, 20.0, 120.0)] as Array[Rect2])
	var unit := RtsFixture.add(battle, &"fixture_footman", FactionData.PLAYER, Vector2(40.0, 40.0))
	var goal := Vector2(280.0, 40.0)
	battle.order_move([unit] as Array[RtsUnit], goal)
	var closed: Array[Vector2] = []
	var arrived := RtsFixture.run_until(battle, func() -> bool:
		if not battle.navigation.is_open(unit.position):
			closed.append(unit.position)
		return unit.order == RtsUnit.Order.IDLE, 30.0)
	assert_true(arrived)
	assert_eq(closed, [] as Array[Vector2], "never in the closed part of the field")
	assert_lt(unit.position.distance_to(goal), 6.0 + RtsBattle.ARRIVE_DISTANCE)

func test_a_blow_takes_the_damage_less_the_armor_once_a_cooldown() -> void:
	var battle := RtsFixture.battle()
	battle.ended.connect(_on_ended)
	var footman := RtsFixture.add(battle, &"fixture_footman", FactionData.PLAYER, Vector2(100.0, 80.0))
	var raider := RtsFixture.add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2(112.0, 80.0))
	var blows: Array[String] = []
	battle.unit_attacked.connect(func(attacker: RtsUnit, target: RtsUnit, amount: int) -> void:
		blows.append("%s %s %d" % [attacker.data.id, target.data.id, amount]))
	battle.advance(0.1)
	assert_eq(blows, ["fixture_footman fixture_raider 6", "fixture_raider fixture_footman 4"] as Array[String], "6 less no armor, 5 less 1")
	battle.advance(0.8)
	assert_eq(blows.size(), 2, "each waits its second")
	battle.advance(0.3)
	assert_eq(blows.size(), 4)
	var fallen: Array[RtsUnit] = []
	battle.unit_defeated.connect(func(unit: RtsUnit) -> void: fallen.append(unit))
	assert_true(RtsFixture.run_until(battle, func() -> bool: return battle.is_over(), 5.0))
	assert_eq(fallen, [raider] as Array[RtsUnit], "24 health is four blows")
	assert_eq(footman.health.current, 30 - 3 * 4, "the footman, placed first, strikes first: the raider falls before its fourth")
	assert_eq(_ended, [true] as Array[bool])
	assert_true(battle.is_won())

func test_a_unit_strong_against_a_kind_hits_it_harder_and_goes_after_it_first() -> void:
	var battle := RtsFixture.battle()
	var footman := RtsFixture.add(battle, &"fixture_footman", FactionData.PLAYER, Vector2(100.0, 80.0))
	var raider := RtsFixture.add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2(100.0, 100.0))
	var brute := RtsFixture.add(battle, &"fixture_brute", FactionData.MONSTERS, Vector2(150.0, 80.0))
	footman.data.strong_against.assign([&"fixture_brute"])
	assert_eq(footman.data.damage_to(brute.data), 6 * 2 - 2, "twice its damage, less the armor")
	assert_eq(footman.data.damage_to(raider.data), 6)
	assert_eq(battle.get_nearest_foe(footman, 60.0), raider)
	assert_eq(battle.get_nearest_foe(footman, 60.0, true), brute, "the brute it sees before the nearer raider")
	assert_eq(battle.get_nearest_foe(footman, 15.0, true), raider, "and the nearest when it sees no brute")
	var blocker := RtsFixture.add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2(112.0, 80.0))
	assert_eq(RtsTargets.choose(battle, footman), blocker, "a foe at its edge before a brute it only sees")
	blocker.health.take(blocker.health.current)
	footman.target_index = -1
	battle.advance(0.1)
	assert_eq(battle.get_unit(footman.target_index), brute, "it goes after the brute")
	var blows: Array[int] = []
	battle.unit_attacked.connect(func(attacker: RtsUnit, _target: RtsUnit, amount: int) -> void:
		if attacker == footman:
			blows.append(amount))
	assert_true(RtsFixture.run_until(battle, func() -> bool: return not blows.is_empty(), 5.0))
	assert_eq(blows, [10] as Array[int], "and strikes it as hard")

func test_units_with_nothing_to_do_go_after_the_foes_they_see_and_no_others() -> void:
	var battle := RtsFixture.battle()
	# The brute sees 50 and stands 55 from the footman's edge, which sees 60.
	var footman := RtsFixture.add(battle, &"fixture_footman", FactionData.PLAYER, Vector2(40.0, 80.0))
	RtsFixture.add(battle, &"fixture_brute", FactionData.MONSTERS, Vector2(107.0, 80.0))
	battle.advance(1.0)
	assert_gt(footman.position.x, 60.0, "it goes after the brute")

	var far := RtsFixture.battle()
	var idle := RtsFixture.add(far, &"fixture_footman", FactionData.PLAYER, Vector2(40.0, 80.0))
	var brute := RtsFixture.add(far, &"fixture_brute", FactionData.MONSTERS, Vector2(117.0, 80.0))
	far.advance(2.0)
	assert_eq(idle.position, Vector2(40.0, 80.0), "65 away: out of its sight")
	assert_eq(brute.position, Vector2(117.0, 80.0))

func test_a_holding_unit_fights_only_what_it_reaches_from_where_it_stands() -> void:
	var battle := RtsFixture.battle()
	var bowman := RtsFixture.add(battle, &"fixture_bowman", FactionData.PLAYER, Vector2(40.0, 80.0))
	# 60 from the bowman's edge: in its sight, out of its reach.
	var raider := RtsFixture.add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2(109.0, 80.0))
	battle.order_hold([bowman] as Array[RtsUnit])
	battle.order_hold([raider] as Array[RtsUnit])
	battle.advance(1.0)
	assert_eq(bowman.position, Vector2(40.0, 80.0))
	assert_eq(raider.health.current, 24, "out of reach")
	battle.order_stop([raider] as Array[RtsUnit])
	assert_true(RtsFixture.run_until(battle, func() -> bool: return raider.health.current < 24, 3.0), "the raider comes, and in reach the bowman shoots")
	assert_true(RtsFixture.run_until(battle, func() -> bool: return bowman.health.current < 20, 5.0), "and they fight")
	assert_eq(bowman.position, Vector2(40.0, 80.0), "it holds, pushed by nothing")

func test_a_move_passes_foes_by_and_an_attack_move_fights_them_and_goes_on() -> void:
	var goal := Vector2(280.0, 80.0)
	var passing := RtsFixture.battle()
	var runner := RtsFixture.add(passing, &"fixture_footman", FactionData.PLAYER, Vector2(40.0, 80.0))
	var watcher := RtsFixture.add(passing, &"fixture_raider", FactionData.MONSTERS, Vector2(160.0, 100.0))
	passing.order_hold([watcher] as Array[RtsUnit])
	passing.order_move([runner] as Array[RtsUnit], goal)
	assert_true(RtsFixture.run_until(passing, func() -> bool: return runner.order == RtsUnit.Order.IDLE, 15.0))
	assert_eq([runner.health.current, watcher.health.current], [30, 24], "it passed the raider by")

	var fighting := RtsFixture.battle()
	var fighter := RtsFixture.add(fighting, &"fixture_footman", FactionData.PLAYER, Vector2(40.0, 80.0))
	var raider := RtsFixture.add(fighting, &"fixture_raider", FactionData.MONSTERS, Vector2(160.0, 100.0))
	# Far off, so the battle goes on once the raider falls.
	var brute := RtsFixture.add(fighting, &"fixture_brute", FactionData.MONSTERS, Vector2(16.0, 156.0))
	fighting.order_hold([raider, brute] as Array[RtsUnit])
	fighting.order_move([fighter] as Array[RtsUnit], goal, true)
	assert_true(RtsFixture.run_until(fighting, func() -> bool: return not raider.is_alive(), 15.0), "it fights the raider it sees")
	assert_eq(fighter.order, RtsUnit.Order.ATTACK_MOVE, "and goes on")
	assert_true(RtsFixture.run_until(fighting, func() -> bool: return fighter.order == RtsUnit.Order.IDLE, 15.0))
	assert_lt(fighter.position.distance_to(goal), 6.0 + RtsBattle.ARRIVE_DISTANCE)

	# Sent on from a fight it is in: it ends the fight there, then goes.
	var engaged := RtsFixture.battle()
	var footman := RtsFixture.add(engaged, &"fixture_footman", FactionData.PLAYER, Vector2(100.0, 80.0))
	var foe := RtsFixture.add(engaged, &"fixture_raider", FactionData.MONSTERS, Vector2(112.0, 80.0))
	var far := RtsFixture.add(engaged, &"fixture_brute", FactionData.MONSTERS, Vector2(16.0, 156.0))
	engaged.order_hold([far] as Array[RtsUnit])
	engaged.order_move([footman] as Array[RtsUnit], goal, true)
	assert_true(RtsFixture.run_until(engaged, func() -> bool: return not foe.is_alive(), 10.0))
	assert_lt(footman.position.distance_to(Vector2(100.0, 80.0)), 12.0, "it fought where it stood")
	assert_true(RtsFixture.run_until(engaged, func() -> bool: return footman.order == RtsUnit.Order.IDLE, 15.0))
	assert_lt(footman.position.distance_to(goal), 6.0 + RtsBattle.ARRIVE_DISTANCE, "and went on to its goal")

func test_an_attack_order_follows_its_foe_anywhere_and_ends_with_it() -> void:
	var battle := RtsFixture.battle()
	var footman := RtsFixture.add(battle, &"fixture_footman", FactionData.PLAYER, Vector2(40.0, 80.0))
	var raider := RtsFixture.add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2(280.0, 80.0))
	# Far off, so the battle goes on once the raider falls.
	var brute := RtsFixture.add(battle, &"fixture_brute", FactionData.MONSTERS, Vector2(16.0, 156.0))
	battle.order_hold([raider, brute] as Array[RtsUnit])
	battle.order_at([footman] as Array[RtsUnit], raider.position + Vector2(2.0, 0.0), 1.0)
	assert_eq(footman.order, RtsUnit.Order.ATTACK, "a right click on a foe attacks it")
	assert_true(RtsFixture.run_until(battle, func() -> bool: return not raider.is_alive(), 20.0))
	battle.advance(RtsBattle.STEP)
	assert_eq(footman.order, RtsUnit.Order.IDLE)
	battle.order_at([footman] as Array[RtsUnit], Vector2(100.0, 40.0))
	assert_eq(footman.order, RtsUnit.Order.MOVE, "on open ground it moves")

func test_the_others_advance_on_their_foes_only_when_the_battle_says_so() -> void:
	var waiting := RtsFixture.battle()
	RtsFixture.add(waiting, &"fixture_footman", FactionData.PLAYER, Vector2(40.0, 80.0))
	var guard := RtsFixture.add(waiting, &"fixture_raider", FactionData.MONSTERS, Vector2(280.0, 80.0))
	waiting.advance(2.0)
	assert_eq(guard.position, Vector2(280.0, 80.0))

	var advancing := RtsFixture.battle()
	advancing.computer_advances = true
	RtsFixture.add(advancing, &"fixture_footman", FactionData.PLAYER, Vector2(40.0, 80.0))
	var raider := RtsFixture.add(advancing, &"fixture_raider", FactionData.MONSTERS, Vector2(280.0, 80.0))
	advancing.advance(2.0)
	assert_eq(raider.order, RtsUnit.Order.ATTACK_MOVE)
	assert_lt(raider.position.x, 280.0 - 50.0, "two seconds of its march")

func test_the_side_that_takes_the_ground_wins_once_it_held_it_long_enough() -> void:
	var battle := RtsFixture.battle()
	battle.hold = RtsHold.new(Rect2(140.0, 60.0, 40.0, 40.0), 3.0, FactionData.PLAYER)
	battle.ended.connect(_on_ended)
	var holders: Array = []
	battle.hold_changed.connect(func(holder: RtsUnit) -> void: holders.append(holder))
	var footman := RtsFixture.add(battle, &"fixture_footman", FactionData.PLAYER, Vector2(160.0, 80.0))
	# A foe out of sight, so only the ground ends the battle.
	var raider := RtsFixture.add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2(300.0, 150.0))
	RtsFixture.add(battle, &"fixture_medic", FactionData.MONSTERS, Vector2(175.0, 95.0))
	battle.advance(2.0)
	assert_eq(holders, [footman], "a foes' healer holds nothing")
	assert_almost_eq(battle.hold.held, 2.0, 0.05)
	assert_almost_eq(battle.hold.get_fraction(), 2.0 / 3.0, 0.02)
	raider.position = Vector2(170.0, 70.0)
	battle.advance(RtsBattle.STEP)
	assert_eq(holders, [footman, null], "foes on it together: no one holds it")
	raider.position = Vector2(300.0, 150.0)
	battle.advance(0.5)
	assert_eq(holders, [footman, null, footman])
	assert_false(battle.is_over(), "the time it held before counts on")
	battle.advance(0.6)
	assert_eq(_ended, [true] as Array[bool])
	assert_true(battle.is_won())
	assert_true(raider.is_alive(), "won with a foe standing")

	var kept := RtsFixture.battle()
	kept.hold = RtsHold.new(Rect2(140.0, 60.0, 40.0, 40.0), 1.0, FactionData.PLAYER)
	RtsFixture.add(kept, &"fixture_footman", FactionData.PLAYER, Vector2(20.0, 20.0))
	var guard := RtsFixture.add(kept, &"fixture_raider", FactionData.MONSTERS, Vector2(160.0, 80.0))
	kept.advance(2.0)
	assert_eq(kept.hold.holder, guard, "a foe on the player's ground holds it")
	assert_false(kept.is_over(), "and keeps it from them, but takes nothing")

	var lost := RtsFixture.battle()
	lost.hold = RtsHold.new(Rect2(140.0, 60.0, 40.0, 40.0), 1.0, FactionData.MONSTERS)
	RtsFixture.add(lost, &"fixture_footman", FactionData.PLAYER, Vector2(20.0, 20.0))
	RtsFixture.add(lost, &"fixture_raider", FactionData.MONSTERS, Vector2(160.0, 80.0))
	lost.advance(1.1)
	assert_true(lost.is_over() and not lost.is_won(), "the foes took their ground")

func test_the_others_advance_on_the_ground_to_hold() -> void:
	var battle := RtsFixture.battle()
	battle.computer_advances = true
	battle.hold = RtsHold.new(Rect2(140.0, 0.0, 40.0, 40.0), 30.0, FactionData.PLAYER)
	RtsFixture.add(battle, &"fixture_footman", FactionData.PLAYER, Vector2(40.0, 150.0))
	var raider := RtsFixture.add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2(280.0, 150.0))
	battle.advance(1.5)
	assert_eq(raider.order, RtsUnit.Order.ATTACK_MOVE)
	assert_eq(raider.goal, Vector2(160.0, 20.0), "to the ground, not the footman")

func test_the_same_orders_play_the_same_battle() -> void:
	var first := _melee()
	var second := _melee()
	assert_eq(first, second)
	assert_true(first.size() > 0)

func test_a_battle_given_up_is_lost() -> void:
	var battle := RtsFixture.battle()
	battle.ended.connect(_on_ended)
	var footman := RtsFixture.add(battle, &"fixture_footman", FactionData.PLAYER, Vector2(40.0, 80.0))
	RtsFixture.add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2(280.0, 80.0))
	battle.forfeit()
	battle.forfeit()
	assert_eq(_ended, [false] as Array[bool])
	assert_true(battle.is_over())
	assert_false(battle.is_won())
	battle.order_move([footman] as Array[RtsUnit], Vector2(100.0, 80.0))
	battle.advance(1.0)
	assert_eq(footman.position, Vector2(40.0, 80.0), "time stops once it is over")

# Ten seconds of four against four with orders on the way: where each unit
# stands and its health.
func _melee() -> Array:
	var battle := RtsFixture.battle(Vector2(320.0, 160.0), [Rect2(150.0, 40.0, 20.0, 80.0)] as Array[Rect2])
	battle.computer_advances = true
	var mine: Array[RtsUnit] = []
	for index in 4:
		mine.append(RtsFixture.add(battle, &"fixture_footman" if index % 2 == 0 else &"fixture_bowman", FactionData.PLAYER, Vector2(30.0, 40.0 + index * 25.0)))
		RtsFixture.add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2(290.0, 40.0 + index * 25.0))
	battle.order_move(mine, Vector2(120.0, 80.0), true)
	battle.advance(3.0)
	battle.order_hold(mine.slice(0, 2))
	battle.advance(7.0)
	return battle.units.map(func(unit: RtsUnit) -> String: return "%s %d" % [unit.position, unit.health.current])

func _on_ended(won: bool) -> void:
	_ended.append(won)
