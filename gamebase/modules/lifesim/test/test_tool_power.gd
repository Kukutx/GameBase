extends GutTest

## What a stronger tool does, on tools and a rock the test builds: it divides
## a farm plot's energy costs by its power and takes that much durability off
## a rock with each hit.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const PLOT_SCENE := preload("res://gamebase/modules/lifesim/farming/farm_plot.tscn")
const ROCK_SCENE := preload("res://gamebase/modules/lifesim/mining/mining_node.tscn")

var _clock_day: int
var _clock_minute: int
var _seed: int
var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _world_snapshot: Dictionary

func before_each() -> void:
	_clock_day = WorldClock.day
	_clock_minute = WorldClock.minute_of_day
	_seed = WeatherState.world_seed
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	# The fixture holds no skills or food buffs, so no perk or buff changes a cost.
	ContentFixture.use(self, [
		_tool(&"fixture_strong_hoe", ItemData.ACTION_TILL, 2),
		_tool(&"fixture_strong_can", ItemData.ACTION_WATER, 2),
		_tool(&"fixture_strong_pickaxe", ItemData.ACTION_MINE, 2),
		_stone(),
		_stone_chunk(),
	])
	InventoryState.clear()
	WorldState.clear()
	WorldClock.set_time(1, 8 * 60)
	# Rain would water the plot as soon as it is tilled.
	while WeatherState.is_raining(1):
		WeatherState.world_seed += 1

func after_each() -> void:
	# GUT frees the fixture after this; restore against the game's content.
	ContentRegistry.active = ContentDB
	InventoryState.load_save_data(_inventory_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	WorldState.load_save_data(_world_snapshot)
	WeatherState.world_seed = _seed
	WorldClock.set_time(_clock_day, _clock_minute)

func test_tool_power_divides_the_energy_a_farm_plot_costs() -> void:
	InventoryState.add_item_by_id(&"fixture_strong_hoe", 1)
	InventoryState.add_item_by_id(&"fixture_strong_can", 1)
	var plot := PLOT_SCENE.instantiate() as FarmPlot
	plot.persistent_id = &""
	plot.hoe_energy_cost = 4
	plot.water_energy_cost = 2
	add_child_autofree(plot)
	await get_tree().process_frame
	PlayerState.energy = 100

	assert_true(plot.use_item(&"fixture_strong_hoe"))
	assert_eq(PlayerState.energy, 98)
	assert_true(plot.use_item(&"fixture_strong_can"))
	assert_eq(PlayerState.energy, 97)

func test_a_pickaxe_as_strong_as_a_rock_is_durable_breaks_it_in_one_hit() -> void:
	InventoryState.add_item_by_id(&"fixture_strong_pickaxe", 1)
	var rock := ROCK_SCENE.instantiate() as MiningNode
	rock.data = MiningNodeData.find(&"fixture_stone")
	rock.persistent_id = &""
	add_child_autofree(rock)
	await get_tree().process_frame

	assert_true(rock.use_item(&"fixture_strong_pickaxe"))
	assert_true(rock.is_depleted)
	assert_eq(InventoryState.get_quantity(&"fixture_stone_chunk"), 1)

func _tool(id: StringName, action: StringName, power: int) -> ItemData:
	var tool := ItemData.new()
	tool.id = id
	tool.kind = ItemData.Kind.TOOL
	tool.tool_action = action
	tool.tool_power = power
	tool.max_stack = 1
	return tool

func _stone() -> MiningNodeData:
	var stone := MiningNodeData.new()
	stone.id = &"fixture_stone"
	stone.durability = 2
	stone.required_tool_power = 1
	stone.drop_item_id = &"fixture_stone_chunk"
	return stone

func _stone_chunk() -> ItemData:
	var chunk := ItemData.new()
	chunk.id = &"fixture_stone_chunk"
	chunk.tags = PackedStringArray(["mined"])
	return chunk
