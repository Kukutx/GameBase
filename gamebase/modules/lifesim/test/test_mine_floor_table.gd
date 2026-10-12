extends GutTest

## MineState's floors and the layouts it generates from a MineFloorTable, on a
## table and mining content the test builds.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

var _world_snapshot: Dictionary
var _seed: int
var _floor_table: MineFloorTable
var _registry: ContentRegistry

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_seed = GameRandom.world_seed
	_floor_table = MineState.floor_table
	# The fixture is the only content even for the tests that build none, so
	# nothing that follows the mine's floors advances the game's own content.
	_registry = ContentFixture.use(self, [
		_rock(&"fixture_stone", 1),
		_rock(&"fixture_iron", 6),
		_rock(&"fixture_gold", 20),
		_enemy(&"fixture_slime"),
		_enemy(&"fixture_deep_slime"),
	])
	MineState.floor_table = null
	WorldState.clear()
	GameRandom.set_seed(93017)
	MineState.enter_from_surface()

func after_each() -> void:
	# GUT frees the fixture after this; restore against the game's content.
	ContentRegistry.active = ContentDB
	MineState.floor_table = _floor_table
	WorldState.load_save_data(_world_snapshot)
	GameRandom.set_seed(_seed)

func test_floor_layout_is_deterministic_unique_and_scales_with_depth() -> void:
	MineState.floor_table = _table(&"fixture_stone", [], [_enemy_tier(&"fixture_slime", 1)])
	var floor2_a := MineState.generate_floor_layout(2)
	var floor2_b := MineState.generate_floor_layout(2)
	var floor20 := MineState.generate_floor_layout(20)
	assert_eq(floor2_a, floor2_b)
	assert_eq(int(floor2_a["floor"]), 2)
	assert_gt((floor2_a["rocks"] as Array).size(), 0)
	assert_gt((floor2_a["enemies"] as Array).size(), 0)
	assert_gte((floor20["rocks"] as Array).size(), (floor2_a["rocks"] as Array).size())
	assert_gte((floor20["enemies"] as Array).size(), (floor2_a["enemies"] as Array).size())
	var ids: Dictionary = {}
	for entry: Dictionary in floor20["rocks"]:
		var id := String(entry["persistent_id"])
		assert_false(ids.has(id))
		ids[id] = true
	for entry: Dictionary in floor20["enemies"]:
		var id := String(entry["persistent_id"])
		assert_false(ids.has(id))
		ids[id] = true

func test_a_floor_generates_nothing_without_a_table() -> void:
	var layout := MineState.generate_floor_layout(10)
	assert_eq(layout["rocks"], [])
	assert_eq(layout["enemies"], [])

func test_a_floor_table_drives_rocks_and_enemies() -> void:
	var gold := _rock_tier(&"fixture_gold", 1.0, 1.0)
	MineState.floor_table = _table(&"fixture_stone", [gold], [_enemy_tier(&"fixture_slime", 1)])
	var floor30 := MineState.generate_floor_layout(30)
	var floor10 := MineState.generate_floor_layout(10)
	for entry: Dictionary in floor30["rocks"]:
		assert_eq(String(entry["kind"]), "fixture_gold")
	for entry: Dictionary in floor10["rocks"]:
		assert_eq(String(entry["kind"]), "fixture_stone", "gold is locked above its minimum floor")
	for entry: Dictionary in floor30["enemies"]:
		assert_eq(String(entry["kind"]), "fixture_slime")

func test_the_first_unlocked_ore_tier_is_guaranteed_on_each_floor() -> void:
	# Tiers rarest first, at chances too low to roll.
	var gold := _rock_tier(&"fixture_gold", 0.0, 0.0)
	var iron := _rock_tier(&"fixture_iron", 0.0, 0.0)
	MineState.floor_table = _table(&"fixture_stone", [gold, iron], [_enemy_tier(&"fixture_slime", 1)])
	assert_eq(_rock_kinds(MineState.generate_floor_layout(5)).count("fixture_iron"), 0, "iron is locked above floor 6")
	var floor6 := _rock_kinds(MineState.generate_floor_layout(6))
	assert_eq(floor6[0], "fixture_iron")
	assert_eq(floor6.count("fixture_iron"), 1)
	assert_eq(floor6.count("fixture_gold"), 0)
	var floor20 := _rock_kinds(MineState.generate_floor_layout(20))
	assert_eq(floor20[0], "fixture_gold", "the rarest unlocked tier comes first")
	assert_eq(floor20.count("fixture_iron"), 0)
	for kind: String in floor20.slice(1):
		assert_eq(kind, "fixture_stone")

func test_each_floor_spawns_the_enemy_of_the_deepest_tier_it_reached() -> void:
	var table := _table(&"fixture_stone", [], [_enemy_tier(&"fixture_deep_slime", 20), _enemy_tier(&"fixture_slime", 1)])
	MineState.floor_table = table
	assert_eq(table.get_enemy_id(1), &"fixture_slime")
	assert_eq(table.get_enemy_id(19), &"fixture_slime")
	assert_eq(table.get_enemy_id(20), &"fixture_deep_slime")
	assert_eq(table.get_enemy_id(MineRunState.MAX_FLOOR), &"fixture_deep_slime")
	for entry: Dictionary in MineState.generate_floor_layout(19)["enemies"]:
		assert_eq(String(entry["kind"]), "fixture_slime")
	var floor20: Array = MineState.generate_floor_layout(20)["enemies"]
	assert_gt(floor20.size(), 0)
	for entry: Dictionary in floor20:
		assert_eq(String(entry["kind"]), "fixture_deep_slime")

func test_a_floor_table_reports_ids_that_are_not_content() -> void:
	var table := _table(&"fixture_stone", [_rock_tier(&"fixture_gold", 0.1, 0.2)], [_enemy_tier(&"fixture_slime", 1)])
	assert_eq(table.find_problems(_registry), PackedStringArray())
	var broken := _table(&"fixture_missing_rock", [_rock_tier(&"fixture_slime", 0.1, 0.2)], [_enemy_tier(&"fixture_stone", 1)])
	assert_eq(broken.find_problems(_registry), PackedStringArray([
		"mine floor table default rock 'fixture_missing_rock' is not a mining node",
		"mine floor table rock tier 'fixture_slime' is not a mining node",
		"mine floor table enemy tier 'fixture_stone' is not an enemy",
	]))

func test_malformed_mine_floor_state_falls_back_to_safe_bounds() -> void:
	WorldState.set_value(&"mine:depth", {"bad": true})
	WorldState.set_value(&"mine:deepest", [999])
	assert_eq(MineState.get_current_floor(), 1)
	assert_eq(MineState.get_deepest_floor(), 1)
	assert_eq(MineState.set_floor(5), 5)
	assert_eq(MineState.get_current_floor(), 5)
	assert_eq(MineState.get_deepest_floor(), 5)

func test_floor_state_and_elevator_checkpoints_are_world_persistent() -> void:
	assert_eq(MineState.get_current_floor(), 1)
	assert_eq(MineState.get_deepest_floor(), 1)
	MineState.set_floor(4)
	assert_eq(MineState.get_current_floor(), 4)
	assert_eq(MineState.get_deepest_floor(), 4)
	assert_eq(MineState.get_deepest_checkpoint(), 1)
	MineState.set_floor(5)
	assert_eq(MineState.get_deepest_floor(), 5)
	assert_eq(MineState.get_deepest_checkpoint(), 5)
	assert_true(MineState.can_use_elevator_floor(1))
	assert_true(MineState.can_use_elevator_floor(5))
	assert_false(MineState.can_use_elevator_floor(4))
	MineState.set_floor(12)
	assert_eq(MineState.get_deepest_checkpoint(), 10)
	assert_eq(Array(MineState.get_elevator_floors()), [1, 5, 10])
	MineState.set_floor(1)
	assert_eq(MineState.get_deepest_floor(), 12)

func test_max_floor_never_leads_deeper() -> void:
	MineState.set_floor(MineRunState.MAX_FLOOR)
	assert_eq(MineState.descend(), MineRunState.MAX_FLOOR)
	assert_eq(MineState.get_current_floor(), MineRunState.MAX_FLOOR)

func _rock(id: StringName, minimum_floor: int) -> MiningNodeData:
	var rock := MiningNodeData.new()
	rock.id = id
	rock.minimum_mine_floor = minimum_floor
	return rock

func _enemy(id: StringName) -> EnemyData:
	var enemy := EnemyData.new()
	enemy.id = id
	return enemy

func _rock_tier(rock_id: StringName, base_chance: float, max_chance: float) -> MineRockTier:
	var tier := MineRockTier.new()
	tier.rock_id = rock_id
	tier.base_chance = base_chance
	tier.max_chance = max_chance
	return tier

func _enemy_tier(enemy_id: StringName, minimum_floor: int) -> EnemyTier:
	var tier := EnemyTier.new()
	tier.enemy_id = enemy_id
	tier.minimum_depth = minimum_floor
	return tier

func _table(default_rock_id: StringName, rock_tiers: Array[MineRockTier], enemy_tiers: Array[EnemyTier]) -> MineFloorTable:
	var table := MineFloorTable.new()
	table.default_rock_id = default_rock_id
	table.rock_tiers = rock_tiers
	table.enemy_tiers = enemy_tiers
	return table

func _rock_kinds(layout: Dictionary) -> Array[String]:
	var kinds: Array[String] = []
	for entry: Dictionary in layout["rocks"]:
		kinds.append(String(entry["kind"]))
	return kinds
