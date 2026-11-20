extends GutTest

## The battle at the ford, the war table's: its map and units hold, the
## battle comes to an end when both sides fight it on their own, and the
## stronger actions recharge.

func test_the_ford_map_sets_up_both_sides_across_the_river() -> void:
	var map := BattleMapData.find(&"border_ford")
	assert_not_null(map)
	assert_eq(map.find_problems(ContentDB), PackedStringArray())
	var battle := AtbBattle.from_map(map)
	assert_eq(battle.units.filter(func(unit: GridUnit) -> bool: return unit.player_controlled).size(), 4)
	assert_eq(battle.units.filter(func(unit: GridUnit) -> bool: return not battle.is_on_player_side(unit)).size(), 4)
	var across := battle.grid.path(Vector2i(1, 2), Vector2i(8, 2))
	assert_true(across.has(Vector2i(5, 3)), "the only way over the river is the ford")
	for cell: Vector2i in [Vector2i(3, 1), Vector2i(3, 5), Vector2i(7, 1), Vector2i(7, 4)]:
		assert_true(battle.grid.is_cover(cell), "woods on both banks give cover")
	assert_true(battle.grid.is_rough(Vector2i(5, 3)), "the ford takes two steps to wade into")

func test_the_battle_ends_when_both_sides_fight_on_their_own() -> void:
	var battle := AtbBattle.from_map(BattleMapData.find(&"border_ford"))
	for unit: GridUnit in battle.units:
		unit.player_controlled = false
	for _frame in 20 * 180:
		battle.advance(1.0 / 20.0)
		if battle.is_over():
			break
	assert_true(battle.is_over(), "one side holds the field within three minutes")

func test_a_volley_a_quake_and_a_prayer_recharge() -> void:
	for pair: Array in [[&"archer", &"volley"], [&"brute", &"quake"], [&"cleric", &"prayer"]]:
		var unit := BattleUnitData.find(pair[0])
		var action := BattleActionData.find(pair[1])
		assert_true(unit.action_ids.has(action.id), "the %s has it" % unit.id)
		assert_gt(action.recharge_turns, 0, "the %s recharges" % action.id)
		assert_ne(unit.action_ids[0], action.id, "and is not the %s's plain action" % unit.id)
	var used: Array[StringName] = []
	var battle := AtbBattle.from_map(BattleMapData.find(&"border_ford"))
	for unit: GridUnit in battle.units:
		unit.player_controlled = false
	battle.unit_acted.connect(func(_unit: GridUnit, action: BattleActionData, _cell: Vector2i, _hits: Array[Dictionary]) -> void: used.append(action.id))
	for _frame in 20 * 180:
		battle.advance(1.0 / 20.0)
		if battle.is_over():
			break
	assert_true(used.has(&"volley"), "the archer looses its volley in a battle: %s" % [used])
