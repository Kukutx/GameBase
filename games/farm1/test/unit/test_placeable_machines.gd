extends GutTest

var _world_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _clock_snapshot: Dictionary
var _inventory_slots: int

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_clock_snapshot = WorldClock.to_save_data()
	_inventory_slots = InventoryState.max_slots
	WorldState.clear()
	InventoryState.clear()
	WorldClock.set_time(1, 8 * 60)

func after_each() -> void:
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	InventoryState.max_slots = _inventory_slots
	WorldClock.load_save_data(_clock_snapshot)

func test_placeable_chests_use_independent_container_ids_and_require_empty_packup() -> void:
	assert_not_null(PlaceableData.find(&"storage_chest"))
	assert_not_null(CraftingState.get_recipe(&"storage_chest"))
	var packed := load("res://gamebase/modules/items/storage/storage_chest.tscn") as PackedScene
	var first := packed.instantiate() as StorageChest
	var second := packed.instantiate() as StorageChest
	first.configure_from_record({"id":"placed_chest_a", "placeable_id":"storage_chest", "location_id":"starter_town", "x":0, "y":0})
	second.configure_from_record({"id":"placed_chest_b", "placeable_id":"storage_chest", "location_id":"starter_town", "x":32, "y":0})
	add_child_autofree(first)
	add_child_autofree(second)
	await get_tree().process_frame

	assert_eq(first.container_id, &"placed_chest_a")
	assert_eq(second.container_id, &"placed_chest_b")
	InventoryState.add_item_by_id(&"wood", 2)
	assert_eq(StorageState.store_item(first.container_id, &"wood", 1, 24), 1)
	assert_eq(StorageState.get_quantity(first.container_id, &"wood"), 1)
	assert_eq(StorageState.get_quantity(second.container_id, &"wood"), 0)
	assert_false(first.can_pack_up())
	assert_eq(StorageState.take_item(first.container_id, &"wood", 1), 1)
	assert_true(first.can_pack_up())
	first.on_removed()
	assert_eq(StorageState.get_used_slots(first.container_id), 0)

func test_packup_waits_for_inventory_space_before_removing_structure() -> void:
	var placements := [{
		"id": "placed_refund_test",
		"placeable_id": "storage_chest",
		"location_id": "starter_town",
		"x": 0.0,
		"y": 0.0,
	}]
	WorldState.set_value(&"building:placements:starter_town", placements)
	InventoryState.max_slots = 1
	InventoryState.add_item_by_id(&"gold_bar", 1)
	assert_false(BuildingState.remove_placement(&"starter_town", &"placed_refund_test", true))
	assert_eq(BuildingState.get_placements(&"starter_town").size(), 1)
	assert_eq(InventoryState.get_quantity(&"storage_chest"), 0)

	InventoryState.clear()
	assert_true(BuildingState.remove_placement(&"starter_town", &"placed_refund_test", true))
	assert_eq(BuildingState.get_placements(&"starter_town").size(), 0)
	assert_eq(InventoryState.get_quantity(&"storage_chest"), 1)

func test_packup_refund_blocks_item_added_reentrancy() -> void:
	WorldState.set_value(&"building:placements:starter_town", [{
		"id": "placed_reentrant_refund",
		"placeable_id": "storage_chest",
		"location_id": "starter_town",
		"x": 0.0,
		"y": 0.0,
	}])
	var observed := {"entered": false, "inner_removed": true}
	var reenter := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"storage_chest" or bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_removed"] = BuildingState.remove_placement(&"starter_town", &"placed_reentrant_refund", true)
	InventoryState.item_added.connect(reenter)
	assert_true(BuildingState.remove_placement(&"starter_town", &"placed_reentrant_refund", true))
	if InventoryState.item_added.is_connected(reenter):
		InventoryState.item_added.disconnect(reenter)
	assert_false(bool(observed["inner_removed"]))
	assert_eq(InventoryState.get_quantity(&"storage_chest"), 1)
	assert_eq(BuildingState.get_placements(&"starter_town").size(), 0)

func test_placeable_furnace_keeps_unique_job_state_and_blocks_packup_until_collected() -> void:
	assert_not_null(PlaceableData.find(&"copper_furnace"))
	assert_not_null(CraftingState.get_recipe(&"copper_furnace"))
	InventoryState.add_item_by_id(&"copper_ore", 2)
	InventoryState.add_item_by_id(&"wood", 1)
	var packed := load("res://game/world/placeables/copper_furnace.tscn") as PackedScene
	var furnace := packed.instantiate() as ProcessingStation
	furnace.configure_from_record({"id":"placed_furnace_a", "placeable_id":"copper_furnace", "location_id":"starter_town", "x":0, "y":0})
	add_child_autofree(furnace)
	await get_tree().process_frame

	assert_eq(furnace.station_id, &"placed_furnace_a")
	assert_true(furnace.start_recipe(&"smelt_copper_bar"))
	assert_false(furnace.can_pack_up())
	assert_true(WorldState.get_value(&"processing:placed_furnace_a", {}) is Dictionary)
	WorldClock.set_time(1, 9 * 60)
	await get_tree().process_frame
	assert_true(furnace.output_ready)
	assert_false(furnace.can_pack_up())
	assert_true(furnace.collect_output())
	assert_true(furnace.can_pack_up())
	furnace.on_removed()
	assert_eq(WorldState.get_value(&"processing:placed_furnace_a", null), null)
