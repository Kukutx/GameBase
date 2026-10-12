extends GutTest

## The content of command battles: what is wrong with a unit or a map, and the
## battle a map sets up.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const RtsFixture := preload("res://gamebase/modules/rts/test/rts_fixture.gd")

var _registry: ContentRegistry

func before_each() -> void:
	_registry = ContentFixture.use(self, RtsFixture.entries())

func test_a_unit_needs_a_name_and_sees_at_least_as_far_as_it_attacks() -> void:
	var unit := RtsUnitData.find(&"fixture_bowman")
	assert_eq(unit.find_problems(_registry), PackedStringArray())
	unit.display_name = ""
	unit.sight_range = 40.0
	assert_eq(unit.find_problems(_registry), PackedStringArray(["has no display name", "sees 40.0, less far than it attacks, 50.0"]))

func test_a_map_places_known_units_on_open_ground_with_both_sides() -> void:
	var map := _map()
	assert_eq(map.find_problems(_registry), PackedStringArray())
	map.obstacles.append(Rect2(500.0, 500.0, 10.0, 10.0))
	map.placements.append(RtsFixture.placement(&"fixture_ghost", FactionData.MONSTERS, Vector2(150.0, 20.0)))
	map.placements.append(RtsFixture.placement(&"fixture_raider", &"", Vector2(100.0, 50.0)))
	map.placements.append(RtsFixture.placement(&"fixture_raider", FactionData.MONSTERS, Vector2(250.0, 50.0)))
	assert_eq(map.find_problems(_registry), PackedStringArray([
		"has obstacle [P: (500.0, 500.0), S: (10.0, 10.0)] outside its field",
		"places unknown unit 'fixture_ghost'",
		"places unit 'fixture_raider' on no side",
		"places unit 'fixture_raider' at (100.0, 50.0), in an obstacle or outside its field",
		"places unit 'fixture_raider' at (250.0, 50.0), in an obstacle or outside its field",
	]))
	var lonely := _map()
	lonely.placements.resize(1)
	assert_eq(lonely.find_problems(_registry), PackedStringArray(["places no unit against the player"]))
	var tiny := _map()
	tiny.size = Vector2(32.0, 100.0)
	assert_eq(tiny.find_problems(_registry), PackedStringArray(["has size (32.0, 100.0) outside (64.0, 64.0) to (2048.0, 2048.0)"]))

func test_a_map_sets_up_its_battle_with_the_player_ordering_their_side() -> void:
	var map := _map()
	map.computer_advances = false
	var battle := RtsBattle.from_map(map)
	assert_eq(battle.size, Vector2(200.0, 100.0))
	assert_false(battle.navigation.is_open(Vector2(100.0, 50.0)))
	assert_false(battle.computer_advances)
	assert_eq(battle.units.map(func(unit: RtsUnit) -> String: return "%s %s %s" % [unit.data.id, unit.position, unit.player_controlled]), [
		"fixture_footman (20.0, 50.0) true",
		"fixture_raider (180.0, 50.0) false",
	])

# A field 200 by 100 with a rock in the middle, a footman at the left and a
# raider at the right.
func _map() -> RtsMapData:
	var map := RtsMapData.new()
	map.id = &"fixture_meadow"
	map.display_name = "Fixture Meadow"
	map.size = Vector2(200.0, 100.0)
	map.obstacles.assign([Rect2(90.0, 40.0, 20.0, 20.0)])
	map.placements.assign([
		RtsFixture.placement(&"fixture_footman", FactionData.PLAYER, Vector2(20.0, 50.0)),
		RtsFixture.placement(&"fixture_raider", FactionData.MONSTERS, Vector2(180.0, 50.0)),
	])
	return map
