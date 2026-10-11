extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

var _clock_day := 1
var _clock_minute := 0
var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _shipping_snapshot: Dictionary

func before_each() -> void:
	_clock_day = WorldClock.day
	_clock_minute = WorldClock.minute_of_day
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_shipping_snapshot = ShippingState.to_save_data()
	ContentFixture.use(self, [_item(&"fixture_turnip", 35), _item(&"fixture_carrot", 50)])
	ShippingState.load_save_data({"pending": {}, "last_day_seen": 1})
	WorldClock.set_time(1, 12 * 60)
	InventoryState.clear()
	PlayerState.money = 100

func after_each() -> void:
	# GUT frees the fixture content after after_each(): restore the saved state
	# against the game's own content.
	ContentRegistry.active = ContentDB
	ShippingState.load_save_data(_shipping_snapshot)
	WorldClock.set_time(_clock_day, _clock_minute)
	InventoryState.load_save_data(_inventory_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)

func test_shipping_removes_item_and_pays_on_next_day() -> void:
	var turnip := ItemData.find(&"fixture_turnip")
	InventoryState.add_item(turnip, 2)
	assert_true(ShippingState.ship_item(&"fixture_turnip", 1))
	assert_eq(InventoryState.get_quantity(&"fixture_turnip"), 1)
	assert_eq(ShippingState.get_pending_quantity(&"fixture_turnip"), 1)
	assert_eq(ShippingState.get_pending_total(), turnip.sell_price)
	assert_eq(PlayerState.money, 100)

	WorldClock.set_time(2, 6 * 60)
	assert_eq(PlayerState.money, 100 + turnip.sell_price)
	assert_eq(ShippingState.get_pending_total(), 0)

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
	PlayerState.money_changed.connect(advance_day)
	WorldClock.set_time(2, 6 * 60)
	if PlayerState.money_changed.is_connected(advance_day):
		PlayerState.money_changed.disconnect(advance_day)
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

func _item(id: StringName, sell_price: int) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	item.kind = ItemData.Kind.CROP
	item.sell_price = sell_price
	return item
