extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

var _inventory_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _wallet_snapshot: Dictionary
var _stone: ItemData
var _chest: ItemData

func before_each() -> void:
	_inventory_snapshot = InventoryState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_wallet_snapshot = Wallet.to_save_data()
	_stone = _item(&"fixture_stone", "Pebble", 99)
	_chest = _item(&"fixture_chest", "Crate", 1)
	ContentFixture.use(self, [_stone, _chest, _item(&"fixture_plank", "Plank", 99), _item(&"fixture_ore", "Ore", 99)])

func after_each() -> void:
	# GUT frees the fixture content only after this hook.
	ContentRegistry.active = ContentDB
	WorldTravel.set("_traveling", false)
	InventoryState.load_save_data(_inventory_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	Wallet.load_save_data(_wallet_snapshot)

func test_inventory_respects_single_slot_stack_limit() -> void:
	var inventory := InventoryStore.new()
	inventory.max_slots = 1
	add_child_autofree(inventory)
	var item := ItemData.new()
	item.id = &"fixture_berry"
	item.display_name = "Wild Berry"
	item.max_stack = 5

	assert_eq(inventory.add_item(item, 3), 0)
	assert_eq(inventory.add_item(item, 4), 2)
	assert_eq(inventory.get_quantity(&"fixture_berry"), 5)
	assert_eq(inventory.get_used_slots(), 1)
	assert_true(inventory.remove_item(&"fixture_berry", 2))
	assert_eq(inventory.get_quantity(&"fixture_berry"), 3)

func test_inventory_supports_multiple_stacks_of_same_item() -> void:
	var inventory := InventoryStore.new()
	inventory.max_slots = 2
	add_child_autofree(inventory)
	var item := ItemData.new()
	item.id = &"fixture_log"
	item.display_name = "Log"
	item.max_stack = 5

	assert_eq(inventory.add_item(item, 9), 0)
	assert_eq(inventory.get_quantity(&"fixture_log"), 9)
	assert_eq(inventory.get_used_slots(), 2)
	assert_eq(inventory.get_slot_entries().size(), 2)
	assert_eq(int(inventory.get_slot_entries()[1]["quantity"]), 4)
	assert_eq(inventory.add_item(item, 3), 2)

func test_atomic_transaction_emits_no_failed_side_effects_and_exposes_final_state_to_listeners() -> void:
	var inventory := InventoryStore.new()
	inventory.max_slots = 1
	add_child_autofree(inventory)
	assert_eq(inventory.add_item(_stone, _stone.max_stack - 1), 0)
	var observed := {"added": 0, "removed": 0, "final_state": true}
	inventory.item_added.connect(func(_item_id: StringName, _quantity: int) -> void:
		observed["added"] = int(observed["added"]) + 1
		observed["final_state"] = bool(observed["final_state"]) and inventory.get_quantity(&"fixture_stone") == 0 and inventory.get_quantity(&"fixture_chest") == 1
	)
	inventory.item_removed.connect(func(_item_id: StringName, _quantity: int) -> void:
		observed["removed"] = int(observed["removed"]) + 1
		observed["final_state"] = bool(observed["final_state"]) and inventory.get_quantity(&"fixture_stone") == 0 and inventory.get_quantity(&"fixture_chest") == 1
	)

	assert_false(inventory.apply_transaction_atomic({}, {"fixture_stone": 2}))
	assert_eq(int(observed["added"]), 0)
	assert_eq(int(observed["removed"]), 0)
	assert_eq(inventory.get_quantity(&"fixture_stone"), _stone.max_stack - 1)

	assert_true(inventory.apply_transaction_atomic({"fixture_stone": _stone.max_stack - 1}, {"fixture_chest": 1}))
	assert_eq(int(observed["removed"]), 1)
	assert_eq(int(observed["added"]), 1)
	assert_true(bool(observed["final_state"]))
	assert_eq(inventory.get_quantity(&"fixture_stone"), 0)
	assert_eq(inventory.get_quantity(&"fixture_chest"), 1)

func test_atomic_transaction_rejects_malformed_quantity_types_without_side_effects() -> void:
	var inventory := InventoryStore.new()
	add_child_autofree(inventory)
	assert_eq(inventory.add_item_by_id(&"fixture_stone", 5), 0)
	var observed := {"changed": 0, "added": 0, "removed": 0}
	inventory.changed.connect(func() -> void: observed["changed"] = int(observed["changed"]) + 1)
	inventory.item_added.connect(func(_id: StringName, _quantity: int) -> void: observed["added"] = int(observed["added"]) + 1)
	inventory.item_removed.connect(func(_id: StringName, _quantity: int) -> void: observed["removed"] = int(observed["removed"]) + 1)
	var before := inventory.to_save_data()
	assert_false(inventory.can_apply_transaction({"fixture_stone": {"bad": true}}, {}))
	assert_false(inventory.apply_transaction_atomic({"fixture_stone": {"bad": true}}, {"fixture_plank": 1}))
	assert_false(inventory.apply_transaction_atomic({"fixture_stone": 1}, {"fixture_plank": "bad"}))
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
	assert_true(inventory.apply_transaction_atomic({"fixture_stone": 0}, {"fixture_plank": 0}))
	assert_true(inventory.add_items_atomic({}))
	assert_true(inventory.add_items_atomic({"fixture_stone": 0}))
	assert_eq(changed_count, 0)
	assert_true(inventory.to_save_data().is_empty())

func test_load_drops_malformed_quantities_and_items_that_are_not_content() -> void:
	var inventory := InventoryStore.new()
	inventory.max_slots = 2
	add_child_autofree(inventory)
	inventory.load_save_data({
		"fixture_stone": {"bad": true},
		"fixture_plank": 3.0,
		"fixture_ore": -4,
		"removed_item": 7,
	})
	assert_eq(inventory.get_quantity(&"fixture_stone"), 0)
	assert_eq(inventory.get_quantity(&"fixture_plank"), 3)
	assert_eq(inventory.get_quantity(&"fixture_ore"), 0)
	assert_eq(inventory.get_quantity(&"removed_item"), 0)
	assert_eq(inventory.to_save_data(), {"fixture_plank": 3})
	assert_eq(inventory.get_used_slots(), 1)

func test_add_items_atomic_adds_all_or_nothing() -> void:
	var inventory := InventoryStore.new()
	inventory.max_slots = 1
	add_child_autofree(inventory)
	assert_false(inventory.add_items_atomic({"fixture_stone": 1, "fixture_plank": 1}))
	assert_false(inventory.add_items_atomic({"removed_item": 1}))
	assert_true(inventory.to_save_data().is_empty())
	assert_true(inventory.add_items_atomic({"fixture_stone": 2}))
	assert_eq(inventory.get_quantity(&"fixture_stone"), 2)

func test_inventory_round_trips_save_data() -> void:
	var source := InventoryStore.new()
	add_child_autofree(source)
	source.add_item(ItemData.find(&"fixture_plank"), 8)

	var restored := InventoryStore.new()
	add_child_autofree(restored)
	restored.load_save_data(source.to_save_data())

	assert_eq(restored.get_quantity(&"fixture_plank"), 8)
	assert_true("Plank x8" in restored.get_summary())

func test_a_new_game_that_cannot_start_leaves_the_inventory_and_hotbar_alone() -> void:
	InventoryState.clear()
	InventoryState.add_item(_stone, 4)
	assert_true(Hotbar.set_slot_item(0, &"fixture_stone"))
	var inventory_before := InventoryState.to_save_data()
	var hotbar_before := Hotbar.to_save_data()
	# A new game checks that it can travel to its start before it resets anything.
	WorldTravel.set("_traveling", true)

	assert_false(GameSession.start_new_game())
	assert_eq(InventoryState.to_save_data(), inventory_before)
	assert_eq(Hotbar.to_save_data(), hotbar_before)

func test_the_module_tells_what_the_player_carries() -> void:
	InventoryState.clear()
	InventoryState.add_item(_stone, 4)
	Hotbar.load_save_data({"slots": ["fixture_stone"], "selected_slot": 0})
	Wallet.set_money(35)
	assert_eq(ItemsModule.new().get_facts(), {"inventory": {
		"money": 35,
		"selected_item_id": "fixture_stone",
		"items": [{"id": "fixture_stone", "display_name": "Pebble", "quantity": 4, "max_stack": 99, "slots": 1}],
	}})

static func _item(id: StringName, display_name: String, max_stack: int) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = display_name
	item.max_stack = max_stack
	return item
