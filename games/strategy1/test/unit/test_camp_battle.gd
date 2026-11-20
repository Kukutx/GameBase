extends GutTest

## The battle at the raider camp, the muster's second: it opens once the pass
## is won, its map and units hold, the raiders wait behind their palisade, and
## the battle comes to an end when the player's troops storm it.

const GATE := Vector2(324.0, 100.0)

func after_each() -> void:
	WorldState.erase(MiniGameDefinition.wins_key(&"pass_battle"))

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
	assert_eq(battle.get_player_units().size(), 9)
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

func test_the_battle_ends_when_the_troops_storm_the_camp() -> void:
	var battle := RtsBattle.from_map(RtsMapData.find(&"raider_camp"))
	battle.order_move(battle.get_player_units(), GATE + Vector2(46.0, 0.0), true)
	for _frame in 20 * 180:
		battle.advance(1.0 / 20.0)
		if battle.is_over():
			break
	assert_true(battle.is_over(), "one side holds the field within three minutes")
