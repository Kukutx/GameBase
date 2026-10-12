extends GutTest

## The content of grid battles: what is wrong with an action, a unit or a map,
## and the battle a map sets up.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const TacticsFixture := preload("res://gamebase/modules/tactics/test/tactics_fixture.gd")

var _registry: ContentRegistry

func before_each() -> void:
	_registry = ContentFixture.use(self, TacticsFixture.entries())

func test_an_action_needs_a_name_a_range_that_holds_and_a_target_besides_its_user() -> void:
	assert_eq(TacticsFixture.action(&"fixture_fine", 3).find_problems(_registry), PackedStringArray())
	var broken := TacticsFixture.action(&"fixture_broken", 3, 3, 1)
	broken.display_name = ""
	assert_eq(broken.find_problems(_registry), PackedStringArray(["has no display name", "has a min range 3 above its max range 1"]))
	assert_eq(TacticsFixture.action(&"fixture_self_harm", 3, 0, 0).find_problems(_registry), PackedStringArray(["does damage only to its user's cell"]))
	assert_eq(TacticsFixture.action(&"fixture_self_heal", 3, 0, 0, 0, true).find_problems(_registry), PackedStringArray())

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
	assert_eq(lonely.find_problems(_registry), PackedStringArray(["places no unit against the player"]))
	var tiny := _map()
	tiny.size = Vector2i(1, 6)
	assert_eq(tiny.find_problems(_registry), PackedStringArray(["has size (1, 6) outside 2x2 to 32x32"]))

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
