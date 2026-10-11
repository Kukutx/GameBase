extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const STATION_SCENE := preload("res://gamebase/modules/lifesim/processing/processing_station.tscn")

var _world_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _clock_snapshot: Dictionary

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_clock_snapshot = WorldClock.to_save_data()
	var recipe := ProcessingRecipeData.new()
	recipe.id = &"fixture_smelt"
	recipe.display_name = "Smelt"
	recipe.inputs = {"fixture_ore": 2, "fixture_fuel": 1}
	recipe.output_item_id = &"fixture_bar"
	recipe.process_minutes = 60
	ContentFixture.use(self, [recipe, _item(&"fixture_ore"), _item(&"fixture_fuel"), _item(&"fixture_bar")])
	WorldState.clear()
	InventoryState.clear()
	WorldClock.set_time(1, 8 * 60)

func after_each() -> void:
	# GUT frees the fixture content after after_each(): restore the saved state
	# against the game's own content.
	ContentRegistry.active = ContentDB
	WorldClock.load_save_data(_clock_snapshot)
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)

func test_placed_station_keeps_unique_job_state_and_blocks_packup_until_collected() -> void:
	InventoryState.add_item_by_id(&"fixture_ore", 2)
	InventoryState.add_item_by_id(&"fixture_fuel", 1)
	var furnace := STATION_SCENE.instantiate() as ProcessingStation
	furnace.recipe_ids = [&"fixture_smelt"]
	furnace.configure_from_record({"id":"placed_furnace_a", "placeable_id":"fixture_furnace", "location_id":"fixture_farm", "x":0, "y":0})
	add_child_autofree(furnace)
	await get_tree().process_frame

	assert_eq(furnace.station_id, &"placed_furnace_a", "a placed station takes its placement id")
	assert_true(furnace.start_recipe(&"fixture_smelt"))
	assert_false(furnace.can_pack_up())
	assert_true(WorldState.get_value(&"processing:placed_furnace_a", {}) is Dictionary)
	WorldClock.set_time(1, 9 * 60)
	await get_tree().process_frame
	assert_true(furnace.output_ready)
	assert_false(furnace.can_pack_up())
	assert_true(furnace.collect_output())
	assert_eq(InventoryState.get_quantity(&"fixture_bar"), 1)
	assert_true(furnace.can_pack_up())
	furnace.on_removed()
	assert_eq(WorldState.get_value(&"processing:placed_furnace_a", null), null)

func _item(id: StringName) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	return item
