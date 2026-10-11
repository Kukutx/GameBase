extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const CONTAINER := &"fixture_chest"

var _world_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _snack: ItemData
var _plank: ItemData

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	StorageState.clear_container(CONTAINER)
	InventoryState.clear()
	_snack = _item(&"fixture_snack", "Snack", 20)
	_plank = _item(&"fixture_plank", "Plank", 99)
	ContentFixture.use(self, [_snack, _plank, _item(&"fixture_stone", "Pebble", 99)])

func after_each() -> void:
	# GUT frees the fixture content only after this hook.
	ContentRegistry.active = ContentDB
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)

func test_storage_respects_stack_based_slot_capacity_and_transfers_both_ways() -> void:
	assert_eq(InventoryState.add_item(_snack, 45), 0)

	assert_eq(StorageState.store_item(CONTAINER, &"fixture_snack", 45, 2), 40)
	assert_eq(InventoryState.get_quantity(&"fixture_snack"), 5)
	assert_eq(StorageState.get_quantity(CONTAINER, &"fixture_snack"), 40)
	assert_eq(StorageState.get_used_slots(CONTAINER), 2)

	assert_eq(StorageState.take_item(CONTAINER, &"fixture_snack", 15), 15)
	assert_eq(InventoryState.get_quantity(&"fixture_snack"), 20)
	assert_eq(StorageState.get_quantity(CONTAINER, &"fixture_snack"), 25)
	assert_eq(StorageState.get_used_slots(CONTAINER), 2)

func test_storage_blocks_same_container_reentrancy_in_both_directions() -> void:
	InventoryState.add_item_by_id(&"fixture_stone", 2)
	var store_observed := {"entered": false, "inner": -1}
	var reenter_store := func(_item_id: StringName, _quantity: int) -> void:
		if bool(store_observed["entered"]):
			return
		store_observed["entered"] = true
		store_observed["inner"] = StorageState.store_item(CONTAINER, &"fixture_stone", 1, 24)
	InventoryState.item_removed.connect(reenter_store)
	assert_eq(StorageState.store_item(CONTAINER, &"fixture_stone", 1, 24), 1)
	if InventoryState.item_removed.is_connected(reenter_store):
		InventoryState.item_removed.disconnect(reenter_store)
	assert_eq(int(store_observed["inner"]), 0)
	assert_eq(InventoryState.get_quantity(&"fixture_stone"), 1)
	assert_eq(StorageState.get_quantity(CONTAINER, &"fixture_stone"), 1)

	InventoryState.clear()
	var take_observed := {"entered": false, "inner": -1}
	var reenter_take := func(_item_id: StringName, _quantity: int) -> void:
		if bool(take_observed["entered"]):
			return
		take_observed["entered"] = true
		take_observed["inner"] = StorageState.take_item(CONTAINER, &"fixture_stone", 1)
	InventoryState.item_added.connect(reenter_take)
	assert_eq(StorageState.take_item(CONTAINER, &"fixture_stone", 1), 1)
	if InventoryState.item_added.is_connected(reenter_take):
		InventoryState.item_added.disconnect(reenter_take)
	assert_eq(int(take_observed["inner"]), 0)
	assert_eq(InventoryState.get_quantity(&"fixture_stone"), 1)
	assert_eq(StorageState.get_quantity(CONTAINER, &"fixture_stone"), 0)

func test_storage_sanitizes_malformed_quantities_without_dropping_legacy_numeric_items() -> void:
	var state_key := StringName("storage:%s" % String(CONTAINER))
	WorldState.set_value(state_key, {
		"fixture_plank": {"bad": true},
		"fixture_stone": -5,
		"fixture_snack": 2,
		"retired_item": 7,
	})
	assert_eq(StorageState.get_quantity(CONTAINER, &"fixture_plank"), 0)
	assert_eq(StorageState.get_quantity(CONTAINER, &"fixture_stone"), 0)
	assert_eq(StorageState.get_quantity(CONTAINER, &"fixture_snack"), 2)
	assert_eq(StorageState.get_used_slots(CONTAINER), 1)
	assert_eq(StorageState.get_entries(CONTAINER).size(), 1)

	InventoryState.add_item_by_id(&"fixture_plank", 1)
	assert_eq(StorageState.store_item(CONTAINER, &"fixture_plank", 1, 24), 1)
	var normalized_raw := WorldState.get_value(state_key, {}) as Dictionary
	assert_eq(int(normalized_raw.get("retired_item", 0)), 7)
	assert_eq(int(normalized_raw.get("fixture_plank", 0)), 1)
	assert_false(normalized_raw.has("fixture_stone"))

func test_storage_persists_through_world_state_snapshot() -> void:
	InventoryState.add_item(_plank, 12)
	assert_eq(StorageState.store_item(CONTAINER, &"fixture_plank", 8, 24), 8)
	var snapshot := WorldState.to_save_data()

	StorageState.clear_container(CONTAINER)
	assert_eq(StorageState.get_quantity(CONTAINER, &"fixture_plank"), 0)
	WorldState.load_save_data(snapshot)
	assert_eq(StorageState.get_quantity(CONTAINER, &"fixture_plank"), 8)

static func _item(id: StringName, display_name: String, max_stack: int) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = display_name
	item.max_stack = max_stack
	return item
