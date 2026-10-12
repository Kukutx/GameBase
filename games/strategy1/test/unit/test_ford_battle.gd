extends GutTest

## The battle at the ford, the war table's: its map and units hold, and the
## battle comes to an end when both sides fight it on their own.

func test_the_ford_map_sets_up_both_sides_across_the_river() -> void:
	var map := BattleMapData.find(&"border_ford")
	assert_not_null(map)
	assert_eq(map.find_problems(ContentDB), PackedStringArray())
	var battle := AtbBattle.from_map(map)
	assert_eq(battle.units.filter(func(unit: GridUnit) -> bool: return unit.player_controlled).size(), 4)
	assert_eq(battle.units.filter(func(unit: GridUnit) -> bool: return not battle.is_on_player_side(unit)).size(), 4)
	var across := battle.grid.path(Vector2i(1, 2), Vector2i(8, 2))
	assert_true(across.has(Vector2i(5, 3)), "the only way over the river is the ford")

func test_the_battle_ends_when_both_sides_fight_on_their_own() -> void:
	var battle := AtbBattle.from_map(BattleMapData.find(&"border_ford"))
	for unit: GridUnit in battle.units:
		unit.player_controlled = false
	for _frame in 20 * 180:
		battle.advance(1.0 / 20.0)
		if battle.is_over():
			break
	assert_true(battle.is_over(), "one side holds the field within three minutes")
