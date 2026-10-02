extends GutTest

func test_inventory_respects_single_slot_stack_limit() -> void:
	var inventory := InventoryStore.new()
	inventory.max_slots = 1
	add_child_autofree(inventory)
	var item := ItemData.new()
	item.id = &"berry"
	item.display_name = "Wild Berry"
	item.max_stack = 5

	assert_eq(inventory.add_item(item, 3), 0)
	assert_eq(inventory.add_item(item, 4), 2)
	assert_eq(inventory.get_quantity(&"berry"), 5)
	assert_eq(inventory.get_used_slots(), 1)
	assert_true(inventory.remove_item(&"berry", 2))
	assert_eq(inventory.get_quantity(&"berry"), 3)

func test_inventory_supports_multiple_stacks_of_same_item() -> void:
	var inventory := InventoryStore.new()
	inventory.max_slots = 2
	add_child_autofree(inventory)
	var item := ItemData.new()
	item.id = &"wood"
	item.display_name = "Wood"
	item.max_stack = 5

	assert_eq(inventory.add_item(item, 9), 0)
	assert_eq(inventory.get_quantity(&"wood"), 9)
	assert_eq(inventory.get_used_slots(), 2)
	assert_eq(inventory.get_slot_entries().size(), 2)
	assert_eq(int(inventory.get_slot_entries()[1]["quantity"]), 4)
	assert_eq(inventory.add_item(item, 3), 2)

func test_atomic_transaction_emits_no_failed_side_effects_and_exposes_final_state_to_listeners() -> void:
	var inventory := InventoryStore.new()
	inventory.max_slots = 1
	add_child_autofree(inventory)
	var stone := ContentDB.get_item(&"stone")
	var chest := ContentDB.get_item(&"storage_chest")
	assert_not_null(stone)
	assert_not_null(chest)
	if stone == null or chest == null:
		return
	assert_eq(inventory.add_item(stone, stone.max_stack - 1), 0)
	var observed := {"added": 0, "removed": 0, "final_state": true}
	inventory.item_added.connect(func(_item_id: StringName, _quantity: int) -> void:
		observed["added"] = int(observed["added"]) + 1
		observed["final_state"] = bool(observed["final_state"]) and inventory.get_quantity(&"stone") == 0 and inventory.get_quantity(&"storage_chest") == 1
	)
	inventory.item_removed.connect(func(_item_id: StringName, _quantity: int) -> void:
		observed["removed"] = int(observed["removed"]) + 1
		observed["final_state"] = bool(observed["final_state"]) and inventory.get_quantity(&"stone") == 0 and inventory.get_quantity(&"storage_chest") == 1
	)

	assert_false(inventory.apply_transaction_atomic({}, {"stone": 2}))
	assert_eq(int(observed["added"]), 0)
	assert_eq(int(observed["removed"]), 0)
	assert_eq(inventory.get_quantity(&"stone"), stone.max_stack - 1)

	assert_true(inventory.apply_transaction_atomic({"stone": stone.max_stack - 1}, {"storage_chest": 1}))
	assert_eq(int(observed["removed"]), 1)
	assert_eq(int(observed["added"]), 1)
	assert_true(bool(observed["final_state"]))
	assert_eq(inventory.get_quantity(&"stone"), 0)
	assert_eq(inventory.get_quantity(&"storage_chest"), 1)

func test_atomic_transaction_rejects_malformed_quantity_types_without_side_effects() -> void:
	var inventory := InventoryStore.new()
	add_child_autofree(inventory)
	assert_eq(inventory.add_item_by_id(&"stone", 5), 0)
	var observed := {"changed": 0, "added": 0, "removed": 0}
	inventory.changed.connect(func() -> void: observed["changed"] = int(observed["changed"]) + 1)
	inventory.item_added.connect(func(_id: StringName, _quantity: int) -> void: observed["added"] = int(observed["added"]) + 1)
	inventory.item_removed.connect(func(_id: StringName, _quantity: int) -> void: observed["removed"] = int(observed["removed"]) + 1)
	var before := inventory.to_save_data()
	assert_false(inventory.can_apply_transaction({"stone": {"bad": true}}, {}))
	assert_false(inventory.apply_transaction_atomic({"stone": {"bad": true}}, {"wood": 1}))
	assert_false(inventory.apply_transaction_atomic({"stone": 1}, {"wood": "bad"}))
	assert_eq(inventory.to_save_data(), before)
	assert_eq(int(observed["changed"]), 0)
	assert_eq(int(observed["added"]), 0)
	assert_eq(int(observed["removed"]), 0)

func test_empty_inventory_transactions_emit_no_fake_change_signal() -> void:
	var inventory := InventoryStore.new()
	add_child_autofree(inventory)
	var changed_count := 0
	inventory.changed.connect(func() -> void: changed_count += 1)
	assert_true(inventory.apply_transaction_atomic({}, {}))
	assert_true(inventory.apply_transaction_atomic({"stone": 0}, {"wood": 0}))
	assert_true(inventory.apply_refund_snapshot_atomic({}))
	assert_true(inventory.apply_refund_snapshot_atomic({"retired": {"quantity": 0, "display_name": "Retired", "max_stack": 1}}))
	assert_eq(changed_count, 0)
	assert_true(inventory.to_save_data().is_empty())

func test_inventory_load_and_refund_snapshot_sanitize_malformed_numeric_metadata() -> void:
	var inventory := InventoryStore.new()
	inventory.max_slots = 2
	add_child_autofree(inventory)
	inventory.load_save_data({
		"stone": {"quantity": {"bad": true}, "display_name": {"bad": true}, "max_stack": [99]},
		"retired_item": {"quantity": 7, "display_name": {"bad": true}, "max_stack": {"bad": true}},
	})
	assert_eq(inventory.get_quantity(&"stone"), 0)
	assert_eq(inventory.get_quantity(&"retired_item"), 7)
	var saved := inventory.to_save_data()
	assert_eq(String((saved["retired_item"] as Dictionary).get("display_name", "")), "retired_item")
	assert_eq(int((saved["retired_item"] as Dictionary).get("max_stack", 0)), 99)

	assert_true(inventory.apply_refund_snapshot_atomic({
		"stone": {"quantity": {"bad": true}},
		"retired_item": {"quantity": 3, "display_name": ["bad"], "max_stack": {"bad": true}},
	}))
	assert_eq(inventory.get_quantity(&"stone"), 0)
	assert_eq(inventory.get_quantity(&"retired_item"), 10)

func test_unknown_legacy_item_is_preserved_without_consuming_capacity() -> void:
	var inventory := InventoryStore.new()
	inventory.max_slots = 1
	add_child_autofree(inventory)
	inventory.load_save_data({
		"removed_item": {
			"quantity": 99,
			"display_name": "Removed Legacy Item",
			"max_stack": 99,
		},
	})
	assert_eq(inventory.get_quantity(&"removed_item"), 99)
	assert_eq(inventory.get_used_slots(), 0)
	assert_eq(inventory.get_free_slots(), 1)
	var entries := inventory.get_entries()
	assert_eq(entries.size(), 1)
	assert_false(bool(entries[0].get("known", true)))
	assert_eq(int(entries[0].get("slots", -1)), 0)
	assert_true(inventory.get_slot_entries().is_empty())

	var stone := ContentDB.get_item(&"stone")
	assert_not_null(stone)
	if stone == null:
		return
	assert_eq(inventory.add_item(stone, 1), 0)
	assert_eq(inventory.get_used_slots(), 1)
	var saved := inventory.to_save_data()
	assert_eq(int((saved["removed_item"] as Dictionary).get("quantity", 0)), 99)
	assert_eq(int((saved["stone"] as Dictionary).get("quantity", 0)), 1)

func test_inventory_round_trips_save_data() -> void:
	var source := InventoryStore.new()
	add_child_autofree(source)
	var item := ItemData.new()
	item.id = &"wood"
	item.display_name = "Wood"
	item.max_stack = 99
	source.add_item(item, 8)

	var restored := InventoryStore.new()
	add_child_autofree(restored)
	restored.load_save_data(source.to_save_data())

	assert_eq(restored.get_quantity(&"wood"), 8)
	assert_true("Wood x8" in restored.get_summary())
