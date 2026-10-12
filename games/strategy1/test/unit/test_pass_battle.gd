extends GutTest

## The battle in the pass, the muster's: its map and units hold, the way from
## one side to the other runs through the pass, and the battle comes to an end
## when both sides fight it on their own.

func test_the_pass_map_sets_up_both_sides_with_the_hills_between() -> void:
	var map := RtsMapData.find(&"hill_pass")
	assert_not_null(map)
	assert_eq(map.find_problems(ContentDB), PackedStringArray())
	assert_eq(MiniGameDefinition.find(&"pass_battle").find_problems(ContentDB), PackedStringArray())
	var battle := RtsBattle.from_map(map)
	assert_eq(battle.get_player_units().size(), 9)
	assert_eq(battle.units.filter(func(unit: RtsUnit) -> bool: return not battle.is_on_player_side(unit)).size(), 10)
	var at := Vector2(60.0, 20.0)
	var way := battle.navigation.find_path(at, Vector2(400.0, 20.0))
	assert_eq(way[way.size() - 1], Vector2(400.0, 20.0))
	# Where the way crosses the hills, a point in every pixel or so.
	var across: Array[Vector2] = []
	for point: Vector2 in way:
		for step in ceili(at.distance_to(point)) + 1:
			var sample := at.move_toward(point, step)
			if sample.x >= 200.0 and sample.x <= 260.0:
				across.append(sample)
		at = point
	assert_false(across.is_empty())
	assert_eq(across.filter(func(sample: Vector2) -> bool: return sample.y <= 72.0 or sample.y >= 128.0), [], "over the hills only through the pass")

func test_the_battle_ends_when_both_sides_fight_on_their_own() -> void:
	var battle := RtsBattle.from_map(RtsMapData.find(&"hill_pass"))
	for unit: RtsUnit in battle.units:
		unit.player_controlled = false
	for _frame in 20 * 180:
		battle.advance(1.0 / 20.0)
		if battle.is_over():
			break
	assert_true(battle.is_over(), "one side holds the field within three minutes")
