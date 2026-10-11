extends GutTest

# Farm1's placeable chest and furnace. How placed chests and processing
# stations keep their state and are packed up is tested on fixture content in
# gamebase/modules/items/test/ and gamebase/modules/lifesim/test/
# (test_placeable_machines.gd).

var _world_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _clock_snapshot: Dictionary

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_clock_snapshot = WorldClock.to_save_data()
	WorldState.clear()
	InventoryState.clear()
	WorldClock.set_time(1, 8 * 60)

func after_each() -> void:
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	WorldClock.load_save_data(_clock_snapshot)

func test_storage_chest_is_a_craftable_placeable() -> void:
	assert_not_null(PlaceableData.find(&"storage_chest"))
	assert_not_null(CraftingState.get_recipe(&"storage_chest"))

func test_copper_furnace_is_a_craftable_placeable_that_smelts_copper() -> void:
	assert_not_null(PlaceableData.find(&"copper_furnace"))
	assert_not_null(CraftingState.get_recipe(&"copper_furnace"))
	InventoryState.add_item_by_id(&"copper_ore", 2)
	InventoryState.add_item_by_id(&"wood", 1)
	var packed := load("res://game/world/placeables/copper_furnace.tscn") as PackedScene
	var furnace := packed.instantiate() as ProcessingStation
	furnace.configure_from_record({"id":"placed_furnace_a", "placeable_id":"copper_furnace", "location_id":"starter_town", "x":0, "y":0})
	add_child_autofree(furnace)
	await get_tree().process_frame

	assert_true(furnace.start_recipe(&"smelt_copper_bar"))
	WorldClock.set_time(1, 9 * 60)
	await get_tree().process_frame
	assert_true(furnace.output_ready)
	assert_true(furnace.collect_output())
	assert_eq(InventoryState.get_quantity(&"copper_bar"), 1)
