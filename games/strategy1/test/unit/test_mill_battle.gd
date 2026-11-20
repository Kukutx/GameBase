extends GutTest

## The battle at the old mill, the war table's second: it opens once the ford
## is won, its map and units hold, the stream is crossed only by the bridge
## and the ford, a win in the pass sends a swordsman, and the battle comes to
## an end when both sides fight it on their own.

func after_each() -> void:
	WorldState.erase(MiniGameDefinition.wins_key(&"ford_battle"))
	WorldState.erase(MiniGameDefinition.wins_key(&"pass_battle"))

func test_the_mill_opens_once_the_ford_is_won() -> void:
	var mill := MiniGameDefinition.find(&"mill_battle")
	assert_eq(mill.find_problems(ContentDB), PackedStringArray())
	assert_false(mill.is_open(), "locked before the ford is won")
	assert_eq(mill.get_requirements(), PackedStringArray(["Win Border Ford"]))
	WorldState.add_int(MiniGameDefinition.wins_key(&"ford_battle"), 1)
	assert_true(mill.is_open())

func test_the_mill_map_sets_up_both_sides_across_the_stream() -> void:
	var map := BattleMapData.find(&"old_mill")
	assert_not_null(map)
	assert_eq(map.find_problems(ContentDB), PackedStringArray())
	var battle := AtbBattle.from_map(map)
	assert_eq(battle.units.filter(func(unit: GridUnit) -> bool: return unit.player_controlled).size(), 5)
	assert_eq(battle.units.filter(func(unit: GridUnit) -> bool: return not battle.is_on_player_side(unit)).size(), 7)
	var upper := battle.grid.path(Vector2i(1, 2), Vector2i(9, 1))
	assert_true(upper.has(Vector2i(6, 1)), "the near way over is the bridge")
	var lower := battle.grid.path(Vector2i(1, 5), Vector2i(9, 6))
	assert_true(lower.has(Vector2i(6, 6)), "and the ford below the mill")
	for cell: Vector2i in [Vector2i(8, 2), Vector2i(8, 5), Vector2i(2, 2), Vector2i(4, 6)]:
		assert_true(battle.grid.is_cover(cell), "the mill's ruins and the woods give cover")
	assert_true(battle.grid.is_rough(Vector2i(6, 6)) and not battle.grid.is_rough(Vector2i(6, 1)), "the ford is slower to cross than the bridge")

func test_a_win_in_the_pass_sends_a_swordsman_to_the_mill() -> void:
	WorldState.add_int(MiniGameDefinition.wins_key(&"pass_battle"), 1)
	var battle := AtbBattle.from_map(BattleMapData.find(&"old_mill"))
	assert_eq(battle.units.filter(func(unit: GridUnit) -> bool: return unit.player_controlled).size(), 6)

func test_the_battle_ends_when_both_sides_fight_on_their_own() -> void:
	var battle := AtbBattle.from_map(BattleMapData.find(&"old_mill"))
	for unit: GridUnit in battle.units:
		unit.player_controlled = false
	for _frame in 20 * 180:
		battle.advance(1.0 / 20.0)
		if battle.is_over():
			break
	assert_true(battle.is_over(), "one side holds the field within three minutes")
