extends GutTest

## A command battle (`RtsBattle`) at scale: the filing (`RtsUnitGrid`) finds
## every unit as near as asked, and a unit finds the same foe through it
## during a step as among all units; the battle knows its foes by faction
## once, allies included; a fallen unit leaves the living; a large battle
## plays the same twice; and a step of one stays within its budget.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const RtsFixture := preload("res://gamebase/modules/rts/test/rts_fixture.gd")
## The units of each army of the large battle.
const ARMY := 150
## What a step of the large battle may take on average: some six times what
## it takes on a desktop, for a slower machine. A step looking at every pair
## of units takes over ten times as long.
const STEP_BUDGET_USEC := 50000

func before_each() -> void:
	ContentFixture.use(self, RtsFixture.entries())

func test_the_filing_finds_every_unit_as_near_as_asked() -> void:
	var rng := GameRandomStream.new("fixture_rts_grid".sha256_buffer())
	var battle := RtsFixture.battle(Vector2(400.0, 300.0))
	for index in 120:
		RtsFixture.add(battle, &"fixture_footman", FactionData.PLAYER if index % 2 == 0 else FactionData.MONSTERS, rng.point_in(Rect2(0.0, 0.0, 400.0, 300.0)))
	var grid := RtsUnitGrid.new(17.0)
	grid.fill(battle.units, 2)
	var both := PackedInt32Array([0, 1])
	for query in 60:
		var point := rng.point_in(Rect2(-20.0, -20.0, 440.0, 340.0))
		var reach := rng.randf_range(0.0, 90.0)
		var near := grid.get_near(point, reach, both)
		for unit: RtsUnit in battle.units:
			if unit.position.distance_to(point) <= reach:
				assert_has(near, unit, "%s within %s of %s" % [unit.position, reach, point])
	assert_eq(grid.get_near(Vector2(200.0, 150.0), 500.0, both).size(), battle.units.size())
	assert_eq(grid.get_near(Vector2(200.0, 150.0), 500.0, PackedInt32Array([1])).filter(func(unit: RtsUnit) -> bool: return unit.faction != FactionData.MONSTERS), [], "only the sides asked for")

func test_the_battle_knows_its_foes_by_faction_allies_included() -> void:
	var guards := FactionData.new()
	guards.id = &"fixture_guards"
	guards.allies = [FactionData.PLAYER]
	ContentFixture.use(self, RtsFixture.entries() + [guards])
	var battle := RtsFixture.battle()
	var footman := RtsFixture.add(battle, &"fixture_footman", FactionData.PLAYER, Vector2(40.0, 80.0))
	var guard := RtsFixture.add(battle, &"fixture_footman", &"fixture_guards", Vector2(60.0, 80.0))
	var raider := RtsFixture.add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2(200.0, 80.0))
	assert_false(battle.are_foes(footman, guard), "allies")
	assert_false(battle.are_foes(guard, footman))
	assert_true(battle.are_foes(guard, raider))
	assert_true(battle.are_foes(raider, footman))
	assert_false(battle.are_foes(raider, raider))
	assert_true(battle.is_on_player_side(guard))
	assert_false(battle.is_on_player_side(raider))
	assert_eq(battle.get_nearest_foe(guard), raider)
	assert_null(battle.get_nearest_foe(guard, 50.0), "out of reach")

func test_a_fallen_unit_leaves_the_living() -> void:
	var battle := RtsFixture.battle()
	var footman := RtsFixture.add(battle, &"fixture_footman", FactionData.PLAYER, Vector2(100.0, 80.0))
	var raider := RtsFixture.add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2(112.0, 80.0))
	RtsFixture.add(battle, &"fixture_brute", FactionData.MONSTERS, Vector2(300.0, 150.0))
	battle.order_hold(battle.units)
	assert_true(RtsFixture.run_until(battle, func() -> bool: return not raider.is_alive(), 10.0))
	battle.advance(RtsBattle.STEP)
	assert_false(battle.get_living_units().has(raider))
	assert_eq(battle.get_living_units().size(), 2)
	assert_eq(battle.units.size(), 3, "every unit keeps its place among the units")
	assert_null(battle.get_unit(raider.index))
	assert_eq(battle.get_nearest_foe(footman), battle.units[2], "the fallen is no foe")

func test_a_unit_finds_the_same_foe_during_a_step_as_among_all_units() -> void:
	var battle := _armies(60)
	var asked := [0]
	var wrong: Array[String] = []
	battle.unit_attacked.connect(func(attacker: RtsUnit, _target: RtsUnit, _amount: int) -> void:
		for within: float in [0.0, 12.0, 40.0, 120.0]:
			asked[0] += 1
			var found := battle.get_nearest_foe(attacker, within)
			var expected := _nearest_foe_among_all(battle, attacker, within)
			if found != expected:
				wrong.append("unit %d within %s" % [attacker.index, within]))
	battle.advance(14.0)
	assert_gt(asked[0], 0, "units fought")
	assert_true(wrong.is_empty(), str(wrong))

func test_a_large_battle_plays_the_same_twice() -> void:
	assert_eq(_snapshot(_armies(60), 5.0), _snapshot(_armies(60), 5.0))

func test_a_step_of_a_large_battle_stays_within_its_budget() -> void:
	var battle := _armies(ARMY)
	var blows := [0]
	battle.unit_attacked.connect(func(_attacker: RtsUnit, _target: RtsUnit, _amount: int) -> void: blows[0] += 1)
	# The march, the meeting and the fight.
	var steps := roundi(12.0 / RtsBattle.STEP)
	var took := 0
	for _step in steps:
		var started := Time.get_ticks_usec()
		battle.advance(RtsBattle.STEP)
		took += Time.get_ticks_usec() - started
	var average := took / steps
	gut.p("%d units: %d usec a step on average" % [ARMY * 2, average])
	assert_gt(blows[0], ARMY, "the armies met and fought")
	assert_lt(average, STEP_BUDGET_USEC)

# Two armies of `army` units each on a wide field, the player's attack-moving
# on the other, which advances.
func _armies(army: int) -> RtsBattle:
	var battle := RtsFixture.battle(Vector2(960.0, 480.0))
	battle.computer_advances = true
	var mine: Array[RtsUnit] = []
	for index in army:
		var row := index % 10
		var column := index / 10
		mine.append(RtsFixture.add(battle, &"fixture_footman" if index % 3 else &"fixture_bowman", FactionData.PLAYER, Vector2(40.0 + column * 14.0, 60.0 + row * 36.0)))
		RtsFixture.add(battle, &"fixture_raider" if index % 4 else &"fixture_brute", FactionData.MONSTERS, Vector2(920.0 - column * 14.0, 60.0 + row * 36.0))
	battle.order_move(mine, Vector2(700.0, 240.0), true)
	return battle

# Where each unit stands and its health after `seconds` of `battle`.
static func _snapshot(battle: RtsBattle, seconds: float) -> Array:
	battle.advance(seconds)
	return battle.units.map(func(unit: RtsUnit) -> String: return "%s %d" % [unit.position, unit.health.current])

# The nearest foe of `unit` within `within`, looking at every unit.
func _nearest_foe_among_all(battle: RtsBattle, unit: RtsUnit, within: float) -> RtsUnit:
	var found: RtsUnit
	var nearest := within
	for other: RtsUnit in battle.units:
		if other != unit and other.is_alive() and battle.are_foes(unit, other):
			var gap := unit.get_gap_to(other)
			if gap <= nearest and (found == null or gap < nearest or other.index < found.index):
				found = other
				nearest = gap
	return found
