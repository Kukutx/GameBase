extends GutTest

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")

var _clock_day := 1
var _clock_minute := 0
var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _vitals_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _shipping_snapshot: Dictionary
var _world_snapshot: Dictionary

func before_each() -> void:
	_clock_day = WorldClock.day
	_clock_minute = WorldClock.minute_of_day
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = Wallet.to_save_data()
	_vitals_snapshot = Vitals.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_shipping_snapshot = ShippingState.to_save_data()
	# A new day makes its listeners (contracts, mail) write to the world.
	_world_snapshot = WorldState.to_save_data()
	ContentFixture.use(self, [_item(&"fixture_turnip", 35), _item(&"fixture_carrot", 50)])
	ShippingState.load_save_data({"pending": {}, "last_day_seen": 1})
	WorldClock.set_time(1, 12 * 60)
	InventoryState.clear()
	Wallet.money = 100

func after_each() -> void:
	# GUT frees the fixture content after after_each(): restore the saved state
	# against the game's own content.
	ContentRegistry.active = ContentDB
	ShippingState.load_save_data(_shipping_snapshot)
	WorldClock.set_time(_clock_day, _clock_minute)
	InventoryState.load_save_data(_inventory_snapshot)
	Wallet.load_save_data(_player_snapshot)
	Vitals.load_save_data(_vitals_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	WorldState.load_save_data(_world_snapshot)

func test_shipping_removes_item_and_pays_on_next_day() -> void:
	var turnip := ItemData.find(&"fixture_turnip")
	InventoryState.add_item(turnip, 2)
	assert_true(ShippingState.ship_item(&"fixture_turnip", 1))
	assert_eq(InventoryState.get_quantity(&"fixture_turnip"), 1)
	assert_eq(ShippingState.get_pending_quantity(&"fixture_turnip"), 1)
	assert_eq(ShippingState.get_pending_total(), turnip.sell_price)
	assert_eq(Wallet.money, 100)

	WorldClock.set_time(2, 6 * 60)
	assert_eq(Wallet.money, 100 + turnip.sell_price)
	assert_eq(ShippingState.get_pending_total(), 0)

func test_a_new_game_pays_its_first_night_after_a_later_day_was_seen() -> void:
	# The previous session reached day 40; its new game starts over at the
	# game's start day, and the clock is reset after the shipping step.
	ShippingState.load_save_data({"pending": {}, "last_day_seen": 40})
	WorldClock.set_time(40, 12 * 60)
	ShippingState.reset_new_game()
	var start_day := GameDefinition.current().start_day
	WorldClock.set_time(start_day, 12 * 60)
	InventoryState.add_item_by_id(&"fixture_turnip", 1)
	assert_true(ShippingState.ship_item(&"fixture_turnip", 1))
	WorldClock.set_time(start_day + 1, 6 * 60)
	assert_eq(Wallet.money, 100 + ItemData.find(&"fixture_turnip").sell_price)

func test_shipping_blocks_item_removed_reentrancy() -> void:
	InventoryState.add_item_by_id(&"fixture_turnip", 2)
	var observed := {"entered": false, "inner_result": true}
	var listener := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"fixture_turnip" or bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_result"] = ShippingState.ship_item(&"fixture_turnip", 1)
	InventoryState.item_removed.connect(listener)
	assert_true(ShippingState.ship_item(&"fixture_turnip", 1))
	if InventoryState.item_removed.is_connected(listener):
		InventoryState.item_removed.disconnect(listener)
	assert_true(bool(observed["entered"]))
	assert_false(bool(observed["inner_result"]))
	assert_eq(InventoryState.get_quantity(&"fixture_turnip"), 1)
	assert_eq(ShippingState.get_pending_quantity(&"fixture_turnip"), 1)

func test_shipping_day_marker_survives_money_callback_advancing_clock() -> void:
	InventoryState.add_item_by_id(&"fixture_turnip", 1)
	assert_true(ShippingState.ship_item(&"fixture_turnip", 1))
	var entered := {"value": false}
	var advance_day := func(_money: int) -> void:
		if bool(entered["value"]):
			return
		entered["value"] = true
		WorldClock.set_time(3, 6 * 60)
	Wallet.money_changed.connect(advance_day)
	WorldClock.set_time(2, 6 * 60)
	if Wallet.money_changed.is_connected(advance_day):
		Wallet.money_changed.disconnect(advance_day)
	assert_eq(WorldClock.day, 3)
	assert_eq(int(ShippingState.to_save_data().get("last_day_seen", 0)), 3)
	assert_eq(ShippingState.get_pending_total(), 0)

	# A shipment created on the nested Day 3 is new business and must survive
	# until a later day rather than being treated as overdue by a stale marker.
	InventoryState.add_item_by_id(&"fixture_carrot", 1)
	assert_true(ShippingState.ship_item(&"fixture_carrot", 1))
	var pending := ShippingState.get_pending_total()
	assert_gt(pending, 0)
	assert_eq(int(ShippingState.to_save_data().get("last_day_seen", 0)), 3)

func test_shipping_load_drops_invalid_pending_values() -> void:
	ShippingState.load_save_data({
		"pending": {
			"fixture_turnip": {"quantity": 2, "value": 180},
			"fixture_carrot": {"quantity": -5, "value": 999},
			"fixture_beet": {"quantity": 3, "value": -50},
			"fixture_leek": "corrupt",
		},
		"last_day_seen": 5,
	})
	var saved := ShippingState.to_save_data()
	var pending := saved["pending"] as Dictionary
	assert_eq(pending.size(), 1)
	assert_true(pending.has("fixture_turnip"))
	assert_eq(int((pending["fixture_turnip"] as Dictionary).get("quantity", 0)), 2)
	assert_eq(int((pending["fixture_turnip"] as Dictionary).get("value", 0)), 180)

func test_shipping_state_round_trips_without_early_payout() -> void:
	var carrot := ItemData.find(&"fixture_carrot")
	InventoryState.add_item(carrot, 1)
	assert_true(ShippingState.ship_item(&"fixture_carrot", 1))
	var saved := ShippingState.to_save_data()
	var expected := ShippingState.get_pending_total()

	ShippingState.load_save_data({"pending": {}, "last_day_seen": 1})
	assert_eq(ShippingState.get_pending_total(), 0)
	ShippingState.load_save_data(saved)
	assert_eq(ShippingState.get_pending_total(), expected)
	assert_eq(int(saved["last_day_seen"]), 1)

func test_the_shipping_menu_ships_the_amount_picked_of_what_the_bin_takes() -> void:
	InventoryState.add_item(ItemData.find(&"fixture_turnip"), 25)
	InventoryState.add_item(ItemData.find(&"fixture_carrot"), 2)
	var menu := (load("res://tiamat/modules/lifesim/economy/shipping_menu.tscn") as PackedScene).instantiate() as ShippingMenu
	add_child_autofree(menu)
	await get_tree().process_frame
	menu.open(&"fixture_turnip")
	assert_eq(menu.item_list.item_count, 2, "every item the bin takes")
	assert_eq(menu.item_list.get_item_text(1), tr("%s x%d — %dg each") % ["Fixture Turnip", 25, 35])
	assert_eq(menu.item_list.get_selected_items(), PackedInt32Array([1]), "the item in hand is picked first")
	assert_eq(menu.ship_selected(), 1)
	menu.amount_button.pressed.emit()
	assert_eq(menu.ship_button.text, tr("Ship %d") % 10)
	assert_false(menu.ship_button.disabled, "the turnips stay picked")
	menu.ship_button.pressed.emit()
	assert_eq(ShippingState.get_pending_quantity(&"fixture_turnip"), 11)
	menu.amount_button.pressed.emit()
	menu.ship_button.grab_focus()
	menu.ship_button.pressed.emit()
	assert_eq([ShippingState.get_pending_quantity(&"fixture_turnip"), InventoryState.get_quantity(&"fixture_turnip")], [25, 0], "all of the stack")
	assert_eq(menu.pending_label.text, tr("Shipping tonight: %dg") % (25 * 35))
	assert_eq(menu.item_list.get_item_metadata(menu.item_list.get_selected_items()[0]), &"fixture_carrot",
		"the entry now in the place of the one gone is picked")
	menu.ship_button.pressed.emit()
	assert_eq(menu.item_list.item_count, 0)
	assert_true(menu.ship_button.disabled)
	assert_true(menu.close_button.has_focus(), "an empty list hands the focus to closing")
	menu.close()

func test_the_bin_takes_neither_tools_nor_quest_items() -> void:
	var hoe := _item(&"fixture_hoe", 10)
	hoe.kind = ItemData.Kind.TOOL
	var letter := _item(&"fixture_letter", 10)
	letter.kind = ItemData.Kind.QUEST
	assert_false(ShippingService.can_ship(hoe))
	assert_false(ShippingService.can_ship(letter))
	assert_false(ShippingService.can_ship(_item(&"fixture_pebble", 0)), "nor an item without a price")
	assert_true(ShippingService.can_ship(ItemData.find(&"fixture_turnip")))

func _item(id: StringName, sell_price: int) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	item.kind = ItemData.Kind.CROP
	item.sell_price = sell_price
	return item
