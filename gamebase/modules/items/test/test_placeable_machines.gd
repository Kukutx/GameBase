extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const CHEST_SCENE := "res://gamebase/modules/items/storage/storage_chest.tscn"

var _world_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _inventory_slots: int

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_inventory_slots = InventoryState.max_slots
	ContentFixture.use(self, _content())
	WorldState.clear()
	InventoryState.clear()

func after_each() -> void:
	# GUT frees the fixture content after after_each(): restore the saved state
	# against the game's own content.
	ContentRegistry.active = ContentDB
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	InventoryState.max_slots = _inventory_slots

func test_placed_chests_use_independent_container_ids_and_require_empty_packup() -> void:
	var packed := load(CHEST_SCENE) as PackedScene
	var first := packed.instantiate() as StorageChest
	var second := packed.instantiate() as StorageChest
	first.configure_from_record({"id":"placed_chest_a", "placeable_id":"fixture_chest", "location_id":"fixture_farm", "x":0, "y":0})
	second.configure_from_record({"id":"placed_chest_b", "placeable_id":"fixture_chest", "location_id":"fixture_farm", "x":32, "y":0})
	add_child_autofree(first)
	add_child_autofree(second)
	await get_tree().process_frame

	assert_eq(first.container_id, &"placed_chest_a")
	assert_eq(second.container_id, &"placed_chest_b")
	InventoryState.add_item_by_id(&"fixture_plank", 2)
	assert_eq(StorageState.store_item(first.container_id, &"fixture_plank", 1, 24), 1)
	assert_eq(StorageState.get_quantity(first.container_id, &"fixture_plank"), 1)
	assert_eq(StorageState.get_quantity(second.container_id, &"fixture_plank"), 0)
	assert_false(first.can_pack_up())
	assert_eq(StorageState.take_item(first.container_id, &"fixture_plank", 1), 1)
	assert_true(first.can_pack_up())
	first.on_removed()
	assert_eq(StorageState.get_used_slots(first.container_id), 0)

func test_packup_waits_for_inventory_space_before_removing_structure() -> void:
	var placements := [{
		"id": "placed_refund_test",
		"placeable_id": "fixture_chest",
		"location_id": "fixture_farm",
		"x": 0.0,
		"y": 0.0,
	}]
	WorldState.set_value(&"building:placements:fixture_farm", placements)
	InventoryState.max_slots = 1
	InventoryState.add_item_by_id(&"fixture_ingot", 1)
	assert_false(BuildingState.remove_placement(&"fixture_farm", &"placed_refund_test", true))
	assert_eq(BuildingState.get_placements(&"fixture_farm").size(), 1)
	assert_eq(InventoryState.get_quantity(&"fixture_chest"), 0)

	InventoryState.clear()
	assert_true(BuildingState.remove_placement(&"fixture_farm", &"placed_refund_test", true))
	assert_eq(BuildingState.get_placements(&"fixture_farm").size(), 0)
	assert_eq(InventoryState.get_quantity(&"fixture_chest"), 1)

func test_packup_refund_blocks_item_added_reentrancy() -> void:
	WorldState.set_value(&"building:placements:fixture_farm", [{
		"id": "placed_reentrant_refund",
		"placeable_id": "fixture_chest",
		"location_id": "fixture_farm",
		"x": 0.0,
		"y": 0.0,
	}])
	var observed := {"entered": false, "inner_removed": true}
	var reenter := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"fixture_chest" or bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_removed"] = BuildingState.remove_placement(&"fixture_farm", &"placed_reentrant_refund", true)
	InventoryState.item_added.connect(reenter)
	assert_true(BuildingState.remove_placement(&"fixture_farm", &"placed_reentrant_refund", true))
	if InventoryState.item_added.is_connected(reenter):
		InventoryState.item_added.disconnect(reenter)
	assert_true(bool(observed["entered"]))
	assert_false(bool(observed["inner_removed"]))
	assert_eq(InventoryState.get_quantity(&"fixture_chest"), 1)
	assert_eq(BuildingState.get_placements(&"fixture_farm").size(), 0)

func _content() -> Array:
	var chest := PlaceableData.new()
	chest.id = &"fixture_chest"
	chest.display_name = "Chest"
	chest.item_id = &"fixture_chest"
	chest.scene_path = CHEST_SCENE
	var chest_item := _item(&"fixture_chest")
	chest_item.kind = ItemData.Kind.PLACEABLE
	chest_item.placeable_id = &"fixture_chest"
	return [chest, chest_item, _item(&"fixture_plank"), _item(&"fixture_ingot")]

func _item(id: StringName) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	return item
