extends GutTest

## A processing station's job on a recipe the test builds: it takes the
## inputs when it starts, finishes by game time, whether or not its scene is
## loaded, and hands over the output when collected.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const STATION_SCENE := preload("res://gamebase/modules/lifesim/processing/processing_station.tscn")

var _clock_day: int
var _clock_minute: int
var _inventory_snapshot: Dictionary
var _world_snapshot: Dictionary

func before_each() -> void:
	_clock_day = WorldClock.day
	_clock_minute = WorldClock.minute_of_day
	_inventory_snapshot = InventoryState.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	var recipe := ProcessingRecipeData.new()
	recipe.id = &"fixture_smelt_bar"
	recipe.display_name = "Fixture Bar"
	recipe.inputs = {"fixture_ore": 2, "fixture_fuel": 1}
	recipe.output_item_id = &"fixture_bar"
	recipe.output_quantity = 1
	recipe.process_minutes = 60
	ContentFixture.use(self, [_item(&"fixture_ore"), _item(&"fixture_fuel"), _item(&"fixture_bar"), recipe])
	InventoryState.clear()
	WorldState.clear()
	WorldClock.set_time(1, 8 * 60)

func after_each() -> void:
	# GUT frees the fixture after this; restore against the game's content.
	ContentRegistry.active = ContentDB
	InventoryState.load_save_data(_inventory_snapshot)
	WorldState.load_save_data(_world_snapshot)
	WorldClock.set_time(_clock_day, _clock_minute)

func test_a_station_consumes_inputs_finishes_by_game_time_and_collects_output() -> void:
	InventoryState.add_item_by_id(&"fixture_ore", 2)
	InventoryState.add_item_by_id(&"fixture_fuel", 1)
	var furnace := _station(&"fixture_furnace")
	add_child_autofree(furnace)
	await get_tree().process_frame

	assert_true(furnace.start_recipe(&"fixture_smelt_bar"))
	assert_eq(InventoryState.get_quantity(&"fixture_ore"), 0)
	assert_eq(InventoryState.get_quantity(&"fixture_fuel"), 0)
	assert_false(furnace.output_ready)
	assert_eq(furnace.get_minutes_remaining(), 60)

	WorldClock.set_time(1, 9 * 60)
	await get_tree().process_frame
	assert_true(furnace.output_ready)
	assert_true(furnace.collect_output())
	assert_eq(InventoryState.get_quantity(&"fixture_bar"), 1)
	assert_eq(furnace.active_recipe_id, &"")

func test_processing_finishes_while_station_scene_is_unloaded() -> void:
	InventoryState.add_item_by_id(&"fixture_ore", 2)
	InventoryState.add_item_by_id(&"fixture_fuel", 1)
	var furnace := _station(&"fixture_offline_furnace")
	add_child(furnace)
	await get_tree().process_frame
	assert_true(furnace.start_recipe(&"fixture_smelt_bar"))
	assert_eq(furnace.get_minutes_remaining(), 60)

	remove_child(furnace)
	furnace.free()
	WorldClock.set_time(1, 10 * 60)

	var restored := _station(&"fixture_offline_furnace")
	add_child_autofree(restored)
	await get_tree().process_frame
	assert_true(restored.output_ready)
	assert_eq(restored.get_minutes_remaining(), 0)
	assert_true(restored.collect_output())
	assert_eq(InventoryState.get_quantity(&"fixture_bar"), 1)

func _station(station_id: StringName) -> ProcessingStation:
	var station := STATION_SCENE.instantiate() as ProcessingStation
	station.station_id = station_id
	station.display_name = "Fixture Furnace"
	station.recipe_ids = [&"fixture_smelt_bar"]
	return station

func _item(id: StringName) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id)
	return item
