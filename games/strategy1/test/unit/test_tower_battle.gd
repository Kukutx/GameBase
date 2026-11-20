extends GutTest

## The battle at the watchtower, the war table's third: it opens once the mill
## is taken, its map and units hold, the tower's walls leave two doors to its
## beacon, a raider who ends a turn on the beacon wins the battle for the
## raiders, a storm of the Raider Camp sends an archer, and the battle comes to
## an end when both sides fight it on their own.

const BEACON := Vector2i(2, 3)

func after_each() -> void:
	WorldState.erase(MiniGameDefinition.wins_key(&"mill_battle"))
	WorldState.erase(MiniGameDefinition.wins_key(&"camp_battle"))

func test_the_watchtower_opens_once_the_mill_is_taken() -> void:
	var tower := MiniGameDefinition.find(&"tower_battle")
	assert_eq(tower.find_problems(ContentDB), PackedStringArray())
	assert_false(tower.is_open(), "locked before the mill is taken")
	assert_eq(tower.get_requirements(), PackedStringArray(["Win Old Mill"]))
	WorldState.add_int(MiniGameDefinition.wins_key(&"mill_battle"), 1)
	assert_true(tower.is_open())

func test_the_tower_s_walls_leave_two_doors_to_its_beacon() -> void:
	var map := BattleMapData.find(&"watchtower")
	assert_not_null(map)
	assert_eq(map.find_problems(ContentDB), PackedStringArray())
	var battle := AtbBattle.from_map(map)
	assert_eq(battle.units.filter(func(unit: GridUnit) -> bool: return unit.player_controlled).size(), 4)
	assert_eq(battle.units.filter(func(unit: GridUnit) -> bool: return not battle.is_on_player_side(unit)).size(), 7)
	assert_eq(battle.goal_cells.keys(), [BEACON])
	assert_true(battle.takes_goals(battle.get_unit_at(Vector2i(8, 2))), "the raiders take the beacon")
	assert_false(battle.takes_goals(battle.get_unit_at(Vector2i(3, 3))), "the banners keep it")
	assert_eq(battle.grid.path(Vector2i(6, 3), BEACON)[-2], Vector2i(3, 3), "in by the east door")
	assert_eq(battle.grid.path(Vector2i(0, 0), BEACON)[-2], Vector2i(1, 3), "or by the west")
	var doors: Dictionary[Vector2i, bool] = {Vector2i(3, 3): true, Vector2i(1, 3): true}
	assert_true(battle.grid.path(Vector2i(6, 3), BEACON, doors).is_empty(), "the swordsmen in the doors bar the way")
	assert_true(battle.grid.is_cover(Vector2i(2, 2)) and battle.grid.is_cover(Vector2i(2, 4)), "the tower shelters who stands inside")
	assert_true(battle.grid.is_rough(Vector2i(5, 3)), "a ditch before the east door")

func test_a_raider_who_ends_a_turn_on_the_beacon_lights_it() -> void:
	var battle := AtbBattle.from_map(BattleMapData.find(&"watchtower"))
	var door := battle.get_unit_at(Vector2i(3, 3))
	var raider := battle.get_unit_at(Vector2i(8, 2))
	# As if the east door's swordsman had fallen, a raider before the door.
	door.health.set_current(0)
	raider.cell = Vector2i(4, 3)
	raider.gauge = AtbBattle.GAUGE_FULL - 0.01
	battle.advance(0.001)
	assert_eq(raider.cell, BEACON, "it runs in")
	assert_true(battle.is_over() and not battle.is_won(), "and the beacon is lit")

func test_a_storm_of_the_raider_camp_sends_an_archer_to_the_tower() -> void:
	WorldState.add_int(MiniGameDefinition.wins_key(&"camp_battle"), 1)
	var battle := AtbBattle.from_map(BattleMapData.find(&"watchtower"))
	assert_eq(battle.units.filter(func(unit: GridUnit) -> bool: return unit.player_controlled).size(), 5)

func test_the_battle_ends_when_both_sides_fight_on_their_own() -> void:
	var battle := AtbBattle.from_map(BattleMapData.find(&"watchtower"))
	for unit: GridUnit in battle.units:
		unit.player_controlled = false
	for _frame in 20 * 180:
		battle.advance(1.0 / 20.0)
		if battle.is_over():
			break
	assert_true(battle.is_over(), "one side holds the field within three minutes")
