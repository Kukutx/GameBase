extends GutTest

## The content of grid battles: what is wrong with an action, a unit or a map,
## and the battle a map sets up.

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")
const TacticsFixture := preload("res://tiamat/modules/tactics/test/tactics_fixture.gd")

var _registry: ContentRegistry

func before_each() -> void:
	_registry = ContentFixture.use(self, TacticsFixture.entries())

func test_an_action_needs_a_name_a_range_that_holds_a_target_besides_its_user_and_delays_only_foes() -> void:
	assert_eq(TacticsFixture.action(&"fixture_fine", 3).find_problems(_registry), PackedStringArray())
	var broken := TacticsFixture.action(&"fixture_broken", 3, 3, 1)
	broken.display_name = ""
	assert_eq(broken.find_problems(_registry), PackedStringArray(["has no display name", "has a min range 3 above its max range 1"]))
	assert_eq(TacticsFixture.action(&"fixture_self_harm", 3, 0, 0).find_problems(_registry), PackedStringArray(["does damage only to its user's cell"]))
	assert_eq(TacticsFixture.action(&"fixture_self_heal", 3, 0, 0, 0, true).find_problems(_registry), PackedStringArray())
	var slowing_heal := TacticsFixture.action(&"fixture_slowing_heal", 3, 0, 1, 0, true)
	slowing_heal.delay = 20.0
	assert_eq(slowing_heal.find_problems(_registry), PackedStringArray(["delays the units it heals"]))
	assert_eq(TacticsFixture.bash().find_problems(_registry), PackedStringArray(), "a blow may delay")

func test_a_unit_needs_a_name_a_speed_and_known_actions() -> void:
	var unit := TacticsFixture.unit(&"fixture_lost", 10, 1, 1, 20.0, 2, [&"fixture_strike", &"fixture_unknown"])
	assert_eq(unit.find_problems(_registry), PackedStringArray(["references unknown action 'fixture_unknown'"]))
	assert_eq(unit.get_actions().map(func(action: BattleActionData) -> StringName: return action.id), [&"fixture_strike"])
	unit.action_ids.clear()
	unit.display_name = ""
	unit.speed = 0.0
	assert_eq(unit.find_problems(_registry), PackedStringArray(["has no display name", "has speed 0.0, not above 0", "has no action"]))

func test_a_map_places_known_units_on_open_cells_one_each_with_both_sides() -> void:
	var map := _map()
	assert_eq(map.find_problems(_registry), PackedStringArray())
	map.placements.append(TacticsFixture.placement(&"fixture_ghost", FactionData.MONSTERS, Vector2i(1, 1)))
	map.placements.append(TacticsFixture.placement(&"fixture_raider", FactionData.MONSTERS, Vector2i(2, 0)))
	map.placements.append(TacticsFixture.placement(&"fixture_raider", FactionData.MONSTERS, Vector2i(0, 0)))
	map.blocked_cells.append(Vector2i(9, 9))
	assert_eq(map.find_problems(_registry), PackedStringArray([
		"blocks cell (9, 9) outside its grid",
		"places unknown unit 'fixture_ghost'",
		"places unit 'fixture_raider' on cell (2, 0), which is blocked or outside its grid",
		"places two units on cell (0, 0)",
	]))
	var lonely := _map()
	lonely.placements.resize(1)
	assert_eq(lonely.find_problems(_registry), PackedStringArray(["places no unit against the player that joins without a condition"]))
	var called := _map()
	called.placements[called.placements.size() - 1].condition = "WORLD_FLAG test:reinforced"
	assert_eq(called.find_problems(_registry), PackedStringArray(["places no unit against the player that joins without a condition"]), "a foe that may not come")
	var late := _map()
	late.placements[late.placements.size() - 1].arrive_seconds = 5.0
	assert_eq(late.find_problems(_registry), PackedStringArray(["places no unit against the player that joins without a condition"]), "nor one still on its way")
	var tiny := _map()
	tiny.size = Vector2i(1, 6)
	assert_eq(tiny.find_problems(_registry), PackedStringArray(["has size (1, 6) outside 2x2 to 32x32"]))

func test_a_map_gives_cover_and_rough_ground_on_its_open_cells() -> void:
	var map := _map()
	map.cover_cells.assign([Vector2i(1, 1), Vector2i(2, 0), Vector2i(7, 7)])
	map.rough_cells.assign([Vector2i(1, 0), Vector2i(2, 0)])
	map.rough_cost = 3
	assert_eq(map.find_problems(_registry), PackedStringArray([
		"gives cover on cell (2, 0), which is blocked or outside its grid",
		"gives cover on cell (7, 7), which is blocked or outside its grid",
		"makes cell (2, 0) rough, which is blocked or outside its grid",
	]))
	var battle := AtbBattle.from_map(map)
	assert_true(battle.grid.is_cover(Vector2i(1, 1)))
	assert_almost_eq(battle.grid.cover_reduction, 0.3, 0.001, "30% less unless the map says otherwise")
	assert_true(battle.grid.is_rough(Vector2i(1, 0)))
	assert_eq(battle.grid.step_cost(Vector2i(1, 0)), 3)
	var knight := battle.get_unit_at(Vector2i(0, 0))
	assert_eq(battle.grid.walk(knight.cell, knight.data.move).get(Vector2i(1, 0)), 3, "the knight's whole move to step onto it")

func test_a_map_s_goals_are_open_cells_no_unit_of_the_side_that_takes_them_starts_on() -> void:
	var map := _map()
	map.goal_cells.assign([Vector2i(3, 0), Vector2i(2, 0), Vector2i(0, 0)])
	assert_eq(map.get_goal_faction(), FactionData.PLAYER, "the player's side takes them unless the map names another")
	assert_eq(map.find_problems(_registry), PackedStringArray([
		"makes cell (2, 0) a goal, which is blocked or outside its grid",
		"places unit 'fixture_knight' on goal cell (0, 0), which its side takes",
	]))
	map.goal_faction_id = FactionData.MONSTERS
	map.goal_cells.assign([Vector2i(0, 0)])
	assert_eq(map.find_problems(_registry), PackedStringArray(), "the foes' goal under the player's unit")
	var battle := AtbBattle.from_map(map)
	assert_eq(battle.goal_cells.keys(), [Vector2i(0, 0)])
	assert_eq(battle.goal_faction, FactionData.MONSTERS)
	assert_true(battle.takes_goals(battle.get_unit_at(Vector2i(3, 2))))
	assert_false(battle.takes_goals(battle.get_unit_at(Vector2i(0, 0))))
	assert_false(AtbBattle.from_map(_map()).takes_goals(battle.get_unit_at(Vector2i(0, 0))), "no goal, no side takes one")

func test_a_map_sets_up_its_battle_with_the_player_commanding_their_side() -> void:
	var settings := TacticsSettings.new()
	settings.time_flows_while_choosing = true
	var battle := AtbBattle.from_map(_map(), settings)
	assert_eq(battle.grid.size, Vector2i(4, 3))
	assert_true(battle.grid.is_blocked(Vector2i(2, 0)))
	assert_eq(battle.units.map(func(unit: GridUnit) -> String: return "%s %s %s" % [unit.data.id, unit.cell, unit.player_controlled]), [
		"fixture_knight (0, 0) true",
		"fixture_raider (3, 2) false",
	])
	assert_true(battle.time_flows_while_choosing)

func test_a_map_s_leader_leads_its_side_one_to_a_side() -> void:
	var map := _map()
	var chief := TacticsFixture.placement(&"fixture_raider", FactionData.MONSTERS, Vector2i(3, 1))
	chief.leader = true
	map.placements.append(chief)
	assert_eq(map.find_problems(_registry), PackedStringArray())
	var battle := AtbBattle.from_map(map)
	assert_true(battle.get_unit_at(Vector2i(3, 1)).leader)
	assert_false(battle.get_unit_at(Vector2i(3, 2)).leader)
	var rival := TacticsFixture.placement(&"fixture_raider", FactionData.MONSTERS, Vector2i(1, 2))
	rival.leader = true
	map.placements.append(rival)
	assert_eq(map.find_problems(_registry), PackedStringArray(["gives side 'monsters' two leaders"]))

func test_a_unit_with_a_condition_joins_only_while_it_holds() -> void:
	var map := _map()
	var reinforcement := TacticsFixture.placement(&"fixture_knight", FactionData.PLAYER, Vector2i(0, 1))
	reinforcement.condition = "WORLD_FLAG test:reinforced"
	map.placements.append(reinforcement)
	assert_eq(map.find_problems(_registry), PackedStringArray())
	var world := WorldState.to_save_data()
	WorldState.clear()
	var without := AtbBattle.from_map(map).units.size()
	WorldState.set_value(&"test:reinforced", true)
	var with := AtbBattle.from_map(map).units.size()
	WorldState.load_save_data(world)
	assert_eq(without, 2)
	assert_eq(with, 3, "the reinforcement joins once the condition holds")

func test_a_unit_placed_to_arrive_later_is_on_its_way_as_the_battle_starts() -> void:
	var map := _map()
	var relief := TacticsFixture.placement(&"fixture_knight", FactionData.PLAYER, Vector2i(0, 1))
	relief.arrive_seconds = 12.0
	relief.leader = true
	map.placements.append(relief)
	assert_eq(map.find_problems(_registry), PackedStringArray())
	var battle := AtbBattle.from_map(map)
	assert_eq(battle.units.size(), 2, "the others are there")
	assert_eq(battle.arrivals.size(), 1)
	var arrival := battle.arrivals.get_all()[0]
	assert_eq([arrival.cell, arrival.seconds, arrival.leader], [Vector2i(0, 1), 12.0, true])
	assert_eq(map.count_player_side(), 2, "it counts toward the units its side can field")

func _map() -> BattleMapData:
	var map := BattleMapData.new()
	map.id = &"fixture_field"
	map.display_name = "Fixture Field"
	map.size = Vector2i(4, 3)
	map.blocked_cells.assign([Vector2i(2, 0)])
	map.placements.assign([
		TacticsFixture.placement(&"fixture_knight", FactionData.PLAYER, Vector2i(0, 0)),
		TacticsFixture.placement(&"fixture_raider", FactionData.MONSTERS, Vector2i(3, 2)),
	])
	return map
