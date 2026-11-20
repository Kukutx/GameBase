extends GutTest

## The battle at the raider camp, the muster's second: it opens once the pass
## is won, its map and units hold, the raiders wait behind their palisade, a
## win at the ford sends two spearmen, the fire at the camp's heart held for
## 20 seconds wins it, and the battle comes to an end when the player's troops
## storm it.

const GATE := Vector2(324.0, 100.0)

func after_each() -> void:
	WorldState.erase(MiniGameDefinition.wins_key(&"pass_battle"))
	WorldState.erase(MiniGameDefinition.wins_key(&"ford_battle"))

func test_the_camp_opens_once_the_pass_is_won() -> void:
	var camp := MiniGameDefinition.find(&"camp_battle")
	assert_eq(camp.find_problems(ContentDB), PackedStringArray())
	assert_false(camp.is_open(), "locked before the pass is won")
	assert_eq(camp.get_requirements(), PackedStringArray(["Win Hill Pass"]))
	WorldState.add_int(MiniGameDefinition.wins_key(&"pass_battle"), 1)
	assert_true(camp.is_open())

func test_the_camp_map_sets_up_both_sides_and_the_way_in_is_the_gate() -> void:
	var map := RtsMapData.find(&"raider_camp")
	assert_not_null(map)
	assert_eq(map.find_problems(ContentDB), PackedStringArray())
	assert_false(map.computer_advances, "the raiders wait for the attack")
	var battle := RtsBattle.from_map(map)
	assert_eq(battle.get_player_units().size(), 10)
	assert_eq(battle.get_player_units().filter(func(unit: RtsUnit) -> bool: return unit.data.heals()).size(), 1, "a field medic among them")
	assert_eq(battle.units.filter(func(unit: RtsUnit) -> bool: return not battle.is_on_player_side(unit)).size(), 12)
	var at := Vector2(60.0, 20.0)
	var way := battle.navigation.find_path(at, Vector2(370.0, 100.0))
	assert_eq(way[way.size() - 1], Vector2(370.0, 100.0))
	# Where the way crosses the palisade's front, a point in every pixel or so.
	var across: Array[Vector2] = []
	for point: Vector2 in way:
		for step in ceili(at.distance_to(point)) + 1:
			var sample := at.move_toward(point, step)
			if sample.x >= 320.0 and sample.x <= 328.0:
				across.append(sample)
		at = point
	assert_false(across.is_empty())
	assert_eq(across.filter(func(sample: Vector2) -> bool: return sample.y < 80.0 or sample.y > 120.0), [], "into the camp only through the gate")

func test_a_win_at_the_ford_sends_two_spearmen_to_the_camp() -> void:
	var map := RtsMapData.find(&"raider_camp")
	WorldState.add_int(MiniGameDefinition.wins_key(&"ford_battle"), 1)
	assert_eq(RtsBattle.from_map(map).get_player_units().size(), 12)

func test_the_fire_at_the_camp_s_heart_held_wins_it() -> void:
	var battle := RtsBattle.from_map(RtsMapData.find(&"raider_camp"))
	assert_eq(battle.hold.seconds, 20.0)
	assert_true(battle.hold.area.has_point(Vector2(370.0, 100.0)), "the fire amid the raiders")
	assert_true(Rect2(328.0, 48.0, 84.0, 104.0).encloses(battle.hold.area), "inside the palisade")
	# As if the troops had driven the raiders out to the field's far corners.
	for unit: RtsUnit in battle.get_living_units():
		if not battle.is_on_player_side(unit):
			unit.position = Vector2(450.0, 12.0) if unit.index % 2 == 0 else Vector2(450.0, 188.0)
			battle.order_hold([unit] as Array[RtsUnit])
	var spear: RtsUnit = battle.get_player_units()[0]
	spear.position = Vector2(370.0, 100.0)
	battle.order_hold([spear] as Array[RtsUnit])
	battle.advance(19.0)
	assert_false(battle.is_over())
	battle.advance(1.1)
	assert_true(battle.is_over() and battle.is_won(), "held for 20 seconds")

func test_the_battle_ends_when_the_troops_storm_the_camp() -> void:
	var battle := RtsBattle.from_map(RtsMapData.find(&"raider_camp"))
	battle.order_move(battle.get_player_units(), GATE + Vector2(46.0, 0.0), true)
	for _frame in 20 * 180:
		battle.advance(1.0 / 20.0)
		if battle.is_over():
			break
	assert_true(battle.is_over(), "one side holds the field within three minutes")
