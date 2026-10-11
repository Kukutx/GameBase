extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const STATION_SCENE := preload("res://gamebase/modules/lifesim/processing/processing_station.tscn")

var _clock_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _world_snapshot: Dictionary
var _inventory_slots: int
var _recipe: ProcessingRecipeData

func before_each() -> void:
	_clock_snapshot = WorldClock.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	_inventory_slots = InventoryState.max_slots
	_recipe = ProcessingRecipeData.new()
	_recipe.id = &"fixture_smelt"
	_recipe.display_name = "Smelt"
	_recipe.inputs = {"fixture_ore": 2, "fixture_fuel": 1}
	_recipe.output_item_id = &"fixture_bar"
	_recipe.output_quantity = 1
	_recipe.process_minutes = 60
	ContentFixture.use(self, [_recipe, _item(&"fixture_ore"), _item(&"fixture_fuel"), _item(&"fixture_bar")])
	InventoryState.clear()
	WorldState.clear()
	WorldClock.set_time(1, 8 * 60)

func after_each() -> void:
	# GUT frees the fixture content after after_each(): restore the saved state
	# against the game's own content.
	ContentRegistry.active = ContentDB
	WorldClock.load_save_data(_clock_snapshot)
	InventoryState.max_slots = _inventory_slots
	InventoryState.load_save_data(_inventory_snapshot)
	WorldState.load_save_data(_world_snapshot)

func test_multi_output_collection_waits_until_the_full_result_fits_without_item_added_side_effects() -> void:
	var output := ItemData.find(&"fixture_bar")
	_recipe.output_quantity = 2
	_add_recipe_inputs(1)
	var furnace := await _add_station(&"test_multi_output_furnace", [&"fixture_smelt"])
	assert_true(furnace.start_recipe(&"fixture_smelt"))
	WorldClock.set_time(1, 9 * 60)
	await get_tree().process_frame
	assert_true(furnace.output_ready)

	InventoryState.clear()
	InventoryState.max_slots = 1
	InventoryState.add_item(output, output.max_stack - 1)
	var observed := {"added": 0}
	var listener := func(_item_id: StringName, _quantity: int) -> void:
		observed["added"] = int(observed["added"]) + 1
	InventoryState.item_added.connect(listener)
	assert_false(furnace.collect_output())
	assert_eq(int(observed["added"]), 0)
	assert_eq(InventoryState.get_quantity(output.id), output.max_stack - 1)
	assert_true(furnace.output_ready)

	assert_true(InventoryState.remove_item(output.id, 1))
	assert_true(furnace.collect_output())
	assert_eq(InventoryState.get_quantity(output.id), output.max_stack)
	assert_false(furnace.output_ready)
	assert_eq(int(observed["added"]), 1)
	if InventoryState.item_added.is_connected(listener):
		InventoryState.item_added.disconnect(listener)

func test_started_job_keeps_promised_output_when_recipe_balance_changes() -> void:
	_add_recipe_inputs(1)
	var furnace := await _add_station(&"test_snapshotted_output_furnace", [&"fixture_smelt"])
	var promised_quantity := _recipe.output_quantity
	assert_true(furnace.start_recipe(&"fixture_smelt"))
	assert_eq(furnace.pending_output_item_id, _recipe.output_item_id)
	assert_eq(furnace.pending_output_quantity, promised_quantity)

	# Simulate a balance patch while this saved job is already in flight.
	_recipe.output_quantity = promised_quantity + 4
	WorldClock.set_time(1, 9 * 60)
	await get_tree().process_frame
	assert_true(furnace.output_ready)
	assert_true(furnace.collect_output())
	assert_eq(InventoryState.get_quantity(&"fixture_bar"), promised_quantity)

func test_processing_load_sanitizes_job_fields_and_drops_a_job_without_output() -> void:
	var station := await _add_station(&"test_malformed_processing_state", [&"fixture_smelt"])
	station.load_state_data({
		"recipe_id": "fixture_smelt",
		"finish_at": {"bad": true},
		"output_ready": {"truthy": true},
		"output_item_id": String(_recipe.output_item_id),
		"output_quantity": _recipe.output_quantity,
	}, false)
	assert_eq(station.active_recipe_id, &"fixture_smelt")
	assert_eq(station.finish_at, 0)
	assert_true(station.output_ready)
	assert_eq(station.pending_output_item_id, _recipe.output_item_id)

	station.load_state_data({
		"recipe_id": "fixture_smelt",
		"finish_at": 1,
		"output_ready": true,
		"output_item_id": ["bad"],
		"output_quantity": {"bad": true},
	}, false)
	assert_eq(station.active_recipe_id, &"")
	assert_false(station.output_ready)
	assert_true(station.can_pack_up())

func test_job_whose_output_is_not_content_is_dropped() -> void:
	var station := await _add_station(&"test_removed_output_station", [])
	station.load_state_data({
		"recipe_id": "removed_recipe",
		"finish_at": 1,
		"output_ready": true,
		"output_item_id": "removed_output_item",
		"output_quantity": 1,
	})
	assert_eq(station.active_recipe_id, &"")
	assert_eq(station.pending_output_item_id, &"")
	assert_eq(station.pending_output_quantity, 0)
	assert_true(station.can_pack_up())

func test_started_job_keeps_its_promised_output_when_its_recipe_is_removed() -> void:
	var station := await _add_station(&"test_removed_recipe_station", [])
	station.load_state_data({
		"recipe_id": "removed_recipe",
		"finish_at": 1,
		"output_ready": true,
		"output_item_id": "fixture_bar",
		"output_quantity": 2,
	})
	assert_eq(station.active_recipe_id, &"removed_recipe")
	assert_true(station.output_ready)
	assert_false(station.can_pack_up())
	assert_true(station.collect_output())
	assert_eq(InventoryState.get_quantity(&"fixture_bar"), 2)
	assert_eq(station.active_recipe_id, &"")
	assert_true(station.can_pack_up())

func test_processing_blocks_inventory_signal_reentrancy_for_start_and_collect() -> void:
	_add_recipe_inputs(2)
	var furnace := await _add_station(&"test_reentrant_furnace", [&"fixture_smelt"])

	var start_observed := {"entered": false, "inner_result": true}
	var remove_listener := func(_item_id: StringName, _quantity: int) -> void:
		if bool(start_observed["entered"]):
			return
		start_observed["entered"] = true
		start_observed["inner_result"] = furnace.start_recipe(&"fixture_smelt")
	InventoryState.item_removed.connect(remove_listener)
	assert_true(furnace.start_recipe(&"fixture_smelt"))
	if InventoryState.item_removed.is_connected(remove_listener):
		InventoryState.item_removed.disconnect(remove_listener)
	assert_true(bool(start_observed["entered"]))
	assert_false(bool(start_observed["inner_result"]))
	for raw_id: Variant in _recipe.inputs.keys():
		assert_eq(InventoryState.get_quantity(StringName(String(raw_id))), int(_recipe.inputs[raw_id]))

	WorldClock.set_time(1, 9 * 60)
	await get_tree().process_frame
	assert_true(furnace.output_ready)
	var output_id := _recipe.output_item_id
	var collect_observed := {"entered": false, "inner_result": true}
	var add_listener := func(item_id: StringName, _quantity: int) -> void:
		if item_id != output_id or bool(collect_observed["entered"]):
			return
		collect_observed["entered"] = true
		collect_observed["inner_result"] = furnace.collect_output()
	InventoryState.item_added.connect(add_listener)
	assert_true(furnace.collect_output())
	if InventoryState.item_added.is_connected(add_listener):
		InventoryState.item_added.disconnect(add_listener)
	assert_true(bool(collect_observed["entered"]))
	assert_false(bool(collect_observed["inner_result"]))
	assert_eq(InventoryState.get_quantity(output_id), _recipe.output_quantity)
	assert_false(furnace.output_ready)

## Puts `times` the recipe's inputs in the inventory.
func _add_recipe_inputs(times: int) -> void:
	for raw_id: Variant in _recipe.inputs.keys():
		InventoryState.add_item_by_id(StringName(String(raw_id)), int(_recipe.inputs[raw_id]) * times)

func _add_station(station_id: StringName, recipe_ids: Array[StringName]) -> ProcessingStation:
	var station := STATION_SCENE.instantiate() as ProcessingStation
	station.station_id = station_id
	station.recipe_ids = recipe_ids
	add_child_autofree(station)
	await get_tree().process_frame
	return station

func _item(id: StringName) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	return item
