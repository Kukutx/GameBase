extends GutTest

var _clock_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _world_snapshot: Dictionary
var _inventory_slots: int
var _original_output_quantity := 1

func before_each() -> void:
	_clock_snapshot = WorldClock.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	_inventory_slots = InventoryState.max_slots
	var recipe := ContentDB.get_processing_recipe(&"smelt_copper_bar")
	if recipe != null:
		_original_output_quantity = recipe.output_quantity
	InventoryState.clear()
	WorldState.clear()
	WorldClock.set_time(1, 8 * 60)

func after_each() -> void:
	var recipe := ContentDB.get_processing_recipe(&"smelt_copper_bar")
	if recipe != null:
		recipe.output_quantity = _original_output_quantity
	InventoryState.max_slots = _inventory_slots
	InventoryState.load_save_data(_inventory_snapshot)
	WorldState.load_save_data(_world_snapshot)
	WorldClock.load_save_data(_clock_snapshot)

func test_multi_output_collection_waits_until_the_full_result_fits_without_item_added_side_effects() -> void:
	var recipe := ContentDB.get_processing_recipe(&"smelt_copper_bar")
	var output := ContentDB.get_item(&"copper_bar")
	assert_not_null(recipe)
	assert_not_null(output)
	if recipe == null or output == null:
		return
	recipe.output_quantity = 2
	InventoryState.add_item_by_id(&"copper_ore", 2)
	InventoryState.add_item_by_id(&"wood", 1)
	var scene := load("res://gamebase/modules/lifesim/processing/processing_station.tscn") as PackedScene
	var furnace := scene.instantiate() as ProcessingStation
	furnace.station_id = &"test_multi_output_furnace"
	furnace.recipe_ids = [&"smelt_copper_bar"]
	add_child_autofree(furnace)
	await get_tree().process_frame
	assert_true(furnace.start_recipe(&"smelt_copper_bar"))
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
	var recipe := ContentDB.get_processing_recipe(&"smelt_copper_bar")
	assert_not_null(recipe)
	if recipe == null:
		return
	for raw_id: Variant in recipe.inputs.keys():
		InventoryState.add_item_by_id(StringName(String(raw_id)), int(recipe.inputs[raw_id]))
	var scene := load("res://gamebase/modules/lifesim/processing/processing_station.tscn") as PackedScene
	var furnace := scene.instantiate() as ProcessingStation
	furnace.station_id = &"test_snapshotted_output_furnace"
	furnace.recipe_ids = [&"smelt_copper_bar"]
	add_child_autofree(furnace)
	await get_tree().process_frame
	var promised_quantity := recipe.output_quantity
	assert_true(furnace.start_recipe(&"smelt_copper_bar"))
	assert_eq(furnace.pending_output_item_id, recipe.output_item_id)
	assert_eq(furnace.pending_output_quantity, promised_quantity)

	# Simulate a balance patch while this saved job is already in flight.
	recipe.output_quantity = promised_quantity + 4
	WorldClock.set_time(1, 9 * 60)
	await get_tree().process_frame
	assert_true(furnace.output_ready)
	assert_true(furnace.collect_output())
	assert_eq(InventoryState.get_quantity(&"copper_bar"), promised_quantity)

func test_processing_load_sanitizes_malformed_job_fields_and_rebuilds_refund_from_recipe() -> void:
	var recipe := ContentDB.get_processing_recipe(&"smelt_copper_bar")
	assert_not_null(recipe)
	if recipe == null:
		return
	var scene := load("res://gamebase/modules/lifesim/processing/processing_station.tscn") as PackedScene
	var station := scene.instantiate() as ProcessingStation
	station.station_id = &"test_malformed_processing_state"
	station.recipe_ids = [&"smelt_copper_bar"]
	add_child_autofree(station)
	await get_tree().process_frame

	station.load_state_data({
		"recipe_id": "smelt_copper_bar",
		"finish_at": {"bad": true},
		"output_ready": {"truthy": true},
		"output_item_id": ["bad"],
		"output_quantity": {"bad": true},
		"input_refund": {"copper_ore": {"quantity": {"bad": true}}},
	}, false)
	assert_eq(station.active_recipe_id, &"smelt_copper_bar")
	assert_true(station.output_ready)
	assert_eq(station.pending_output_item_id, recipe.output_item_id)
	assert_eq(station.pending_output_quantity, recipe.output_quantity)
	for raw_id: Variant in recipe.inputs.keys():
		var refund_entry := station.pending_input_refund.get(String(raw_id), {}) as Dictionary
		assert_eq(int(refund_entry.get("quantity", 0)), int(recipe.inputs[raw_id]))

func test_removed_output_refunds_snapshotted_inputs_before_unlocking_station() -> void:
	var scene := load("res://gamebase/modules/lifesim/processing/processing_station.tscn") as PackedScene
	var station := scene.instantiate() as ProcessingStation
	station.station_id = &"test_removed_output_refund_station"
	station.recipe_ids = []
	add_child_autofree(station)
	await get_tree().process_frame

	InventoryState.clear()
	InventoryState.max_slots = 1
	var stone := ContentDB.get_item(&"stone")
	assert_not_null(stone)
	if stone == null:
		return
	InventoryState.add_item(stone, stone.max_stack)
	station.load_state_data({
		"recipe_id": "retired_recipe",
		"finish_at": 1,
		"output_ready": true,
		"output_item_id": "removed_output_item",
		"output_quantity": 1,
		"input_refund": {
			"copper_ore": {"quantity": 2, "display_name": "Copper Ore", "max_stack": 99},
			"wood": {"quantity": 1, "display_name": "Wood", "max_stack": 99},
		},
	})
	assert_false(station.collect_output())
	assert_ne(station.active_recipe_id, &"")
	assert_eq(InventoryState.get_quantity(&"copper_ore"), 0)
	assert_eq(InventoryState.get_quantity(&"wood"), 0)

	InventoryState.clear()
	InventoryState.max_slots = 2
	assert_false(station.collect_output())
	assert_eq(station.active_recipe_id, &"")
	assert_eq(InventoryState.get_quantity(&"copper_ore"), 2)
	assert_eq(InventoryState.get_quantity(&"wood"), 1)
	assert_true(station.can_pack_up())

	InventoryState.clear()
	# If an input definition also disappeared, preserve its snapshotted quantity
	# as an isolated legacy inventory entry instead of discarding player value.
	station.load_state_data({
		"recipe_id": "retired_recipe_2",
		"finish_at": 1,
		"output_ready": true,
		"output_item_id": "removed_output_item_2",
		"output_quantity": 1,
		"input_refund": {
			"removed_input_item": {"quantity": 4, "display_name": "Retired Material", "max_stack": 12},
		},
	})
	assert_false(station.collect_output())
	assert_eq(station.active_recipe_id, &"")
	assert_eq(InventoryState.get_quantity(&"removed_input_item"), 4)
	assert_eq(InventoryState.get_used_slots(), 0)
	var saved_inventory := InventoryState.to_save_data()
	assert_eq(String((saved_inventory["removed_input_item"] as Dictionary).get("display_name", "")), "Retired Material")

func test_removed_recipe_job_uses_saved_output_snapshot_and_legacy_orphan_unlocks() -> void:
	var scene := load("res://gamebase/modules/lifesim/processing/processing_station.tscn") as PackedScene
	var station := scene.instantiate() as ProcessingStation
	station.station_id = &"test_removed_recipe_station"
	station.recipe_ids = []
	add_child_autofree(station)
	await get_tree().process_frame

	station.load_state_data({
		"recipe_id": "retired_recipe",
		"finish_at": 1,
		"output_ready": true,
		"output_item_id": "copper_bar",
		"output_quantity": 2,
	})
	assert_eq(station.active_recipe_id, &"retired_recipe")
	assert_true(station.output_ready)
	assert_false(station.can_pack_up())
	assert_true(station.collect_output())
	assert_eq(InventoryState.get_quantity(&"copper_bar"), 2)
	assert_eq(station.active_recipe_id, &"")
	assert_true(station.can_pack_up())

	# Pre-snapshot saves cannot infer an output after the recipe disappears. They
	# should normalize to idle immediately rather than remain invisibly locked.
	station.load_state_data({
		"recipe_id": "retired_recipe",
		"finish_at": 999999,
		"output_ready": false,
	})
	assert_eq(station.active_recipe_id, &"")
	assert_eq(station.pending_output_item_id, &"")
	assert_eq(station.pending_output_quantity, 0)
	assert_true(station.can_pack_up())

func test_processing_blocks_inventory_signal_reentrancy_for_start_and_collect() -> void:
	var recipe := ContentDB.get_processing_recipe(&"smelt_copper_bar")
	assert_not_null(recipe)
	if recipe == null:
		return
	for raw_id: Variant in recipe.inputs.keys():
		InventoryState.add_item_by_id(StringName(String(raw_id)), int(recipe.inputs[raw_id]) * 2)
	var scene := load("res://gamebase/modules/lifesim/processing/processing_station.tscn") as PackedScene
	var furnace := scene.instantiate() as ProcessingStation
	furnace.station_id = &"test_reentrant_furnace"
	furnace.recipe_ids = [&"smelt_copper_bar"]
	add_child_autofree(furnace)
	await get_tree().process_frame

	var start_observed := {"entered": false, "inner_result": true}
	var remove_listener := func(_item_id: StringName, _quantity: int) -> void:
		if bool(start_observed["entered"]):
			return
		start_observed["entered"] = true
		start_observed["inner_result"] = furnace.start_recipe(&"smelt_copper_bar")
	InventoryState.item_removed.connect(remove_listener)
	assert_true(furnace.start_recipe(&"smelt_copper_bar"))
	if InventoryState.item_removed.is_connected(remove_listener):
		InventoryState.item_removed.disconnect(remove_listener)
	assert_true(bool(start_observed["entered"]))
	assert_false(bool(start_observed["inner_result"]))
	for raw_id: Variant in recipe.inputs.keys():
		assert_eq(InventoryState.get_quantity(StringName(String(raw_id))), int(recipe.inputs[raw_id]))

	WorldClock.set_time(1, 9 * 60)
	await get_tree().process_frame
	assert_true(furnace.output_ready)
	var output_id := recipe.output_item_id
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
	assert_eq(InventoryState.get_quantity(output_id), recipe.output_quantity)
	assert_false(furnace.output_ready)
