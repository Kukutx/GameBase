extends GutTest

## A shop's counter (`ShopMenu`): its sell list follows the inventory in
## place, the focus stays on the list as stacks sell out, it tells of the
## item whose button has the focus, one press buys or sells the amount the
## player picks, and a purchase the player cannot make now is dimmed until a
## sale pays for it.

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")
const SHOP_MENU := preload("res://tiamat/modules/items/shop/shop_menu.tscn")

var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _vitals_snapshot: Dictionary
var _world_snapshot: Dictionary
var _shop: ShopData

func before_each() -> void:
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = Wallet.to_save_data()
	_vitals_snapshot = Vitals.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	_shop = ShopData.new()
	_shop.id = &"fixture_counter"
	_shop.display_name = "Counter"
	ContentFixture.use(self, [_item(&"fixture_berry", "Berry", 5), _item(&"fixture_pebble", "Pebble", 3), _shop])
	InventoryState.clear()
	Wallet.reset_new_game()
	Vitals.reset_new_game()
	InventoryState.add_item_by_id(&"fixture_berry", 2)
	InventoryState.add_item_by_id(&"fixture_pebble", 1)

func after_each() -> void:
	# GUT frees the fixture content only after this hook.
	ContentRegistry.active = ContentDB
	InventoryState.load_save_data(_inventory_snapshot)
	Wallet.load_save_data(_player_snapshot)
	Vitals.load_save_data(_vitals_snapshot)
	WorldState.load_save_data(_world_snapshot)

func test_selling_keeps_the_buttons_in_place_and_the_focus_on_the_list() -> void:
	var money := Wallet.money
	var menu := SHOP_MENU.instantiate() as ShopMenu
	add_child_autofree(menu)
	menu.open(_shop)
	var buttons := _sell_buttons(menu)
	assert_eq(buttons.size(), 2)
	assert_eq(_focused(menu), buttons[0], "a shop with nothing to buy starts on its first sale")
	buttons[0].pressed.emit()
	assert_eq(_sell_buttons(menu), buttons, "a sale changes the buttons in place")
	assert_eq(buttons[0].text, "Sell Berry (1) — 5g")
	assert_eq(_focused(menu), buttons[0])
	buttons[0].pressed.emit()
	assert_eq(_sell_buttons(menu), [buttons[1]], "a stack sold out takes its button")
	assert_eq(_focused(menu), buttons[1], "the focus goes to the sale after it")
	buttons[1].pressed.emit()
	assert_eq(_sell_buttons(menu), [])
	assert_eq(_focused(menu), menu.close_button, "with nothing left to sell, to the close button")
	assert_false(menu.sell_title.visible)
	assert_eq(Wallet.money, money + 2 * 5 + 3)
	menu.close()

func test_the_counter_tells_of_the_item_whose_button_has_the_focus() -> void:
	ItemData.find(&"fixture_berry").description = "Sweet."
	ItemData.find(&"fixture_pebble").description = "Smooth."
	_shop.stock = {"fixture_pebble": 4}
	Wallet.set_money(30)
	var menu := SHOP_MENU.instantiate() as ShopMenu
	add_child_autofree(menu)
	menu.open(_shop)
	assert_eq(menu.about_label.text, "Smooth.", "the pebble's, whose purchase starts with the focus")
	var buttons := _sell_buttons(menu)
	(buttons[0] as Button).grab_focus()
	assert_eq(menu.about_label.text, "Sweet.", "the berry's, as its sale takes the focus")
	menu.close_button.grab_focus()
	assert_eq(menu.about_label.text, "Sweet.", "kept while the focus is on no item")
	assert_gt(menu.about_label.custom_minimum_size.y, 0.0, "two lines kept for it")
	menu.close()

func test_one_press_buys_or_sells_the_amount_the_player_picks() -> void:
	_shop.stock = {"fixture_pebble": 4}
	Wallet.set_money(30)
	var menu := SHOP_MENU.instantiate() as ShopMenu
	add_child_autofree(menu)
	menu.open(_shop)
	var buy := menu.items_container.get_child(0) as Button
	assert_true(menu.amount_button.visible)
	assert_eq([menu.get_amount(), menu.amount_button.text, buy.text], [1, "Amount: 1", "Buy Pebble — 4g"])
	menu.amount_button.grab_focus()
	menu.amount_button.pressed.emit()
	assert_eq([menu.get_amount(), menu.amount_button.text, buy.text], [5, "Amount: 5", "Buy Pebble x5 — 20g"])
	assert_eq(_focused(menu), menu.amount_button, "the focus stays on the amount")
	assert_eq((_sell_buttons(menu)[0] as Button).text, "Sell Berry (2) x2 — 10g", "a sale of as many as the player holds")
	buy.pressed.emit()
	assert_eq([InventoryState.get_quantity(&"fixture_pebble"), Wallet.money], [6, 10], "five at a press")
	menu.amount_button.pressed.emit()
	assert_eq(menu.get_amount(), 10)
	buy.pressed.emit()
	assert_eq([InventoryState.get_quantity(&"fixture_pebble"), Wallet.money], [8, 2], "as many as the money left buys")
	(_sell_buttons(menu)[0] as Button).pressed.emit()
	assert_eq(InventoryState.get_quantity(&"fixture_berry"), 0, "both berries the player held")
	menu.amount_button.pressed.emit()
	Wallet.set_money(14)
	assert_eq([menu.get_amount(), menu.amount_button.text, buy.text], [0, "Amount: All", "Buy Pebble x3 — 12g"],
		"all is as many as the money pays for")
	assert_eq((_sell_buttons(menu)[0] as Button).text, "Sell Pebble (8) x8 — 24g", "and every one held")
	buy.pressed.emit()
	assert_eq([InventoryState.get_quantity(&"fixture_pebble"), Wallet.money], [11, 2])
	assert_eq([buy.text, buy.disabled], ["Buy Pebble — 4g", true], "none left to buy tells the price of one")
	(_sell_buttons(menu)[0] as Button).pressed.emit()
	assert_eq([InventoryState.get_quantity(&"fixture_pebble"), Wallet.money], [0, 35], "all eleven sold")
	menu.amount_button.pressed.emit()
	assert_eq(menu.get_amount(), 1, "round to one again")
	menu.close()
	menu.amount_button.pressed.emit()
	menu.open(_shop)
	assert_eq(menu.get_amount(), 1, "a counter opens on the first amount")
	menu.amounts = PackedInt32Array([1])
	menu.open(_shop)
	assert_false(menu.amount_button.visible, "one amount needs no button")
	menu.close()

func test_a_purchase_the_player_cannot_make_is_dimmed_until_a_sale_pays_for_it() -> void:
	_shop.stock = {"fixture_pebble": 4}
	var offer := FixtureOffer.new()
	_shop.offers.append(offer)
	Wallet.set_money(3)
	var menu := SHOP_MENU.instantiate() as ShopMenu
	add_child_autofree(menu)
	menu.open(_shop)
	var pebble := menu.items_container.get_child(0) as Button
	var service := menu.items_container.get_child(1) as Button
	assert_eq([pebble.disabled, service.disabled], [true, true], "3g buys neither")
	assert_eq(_focused(menu), _sell_buttons(menu)[0], "so the counter starts on the first sale")
	assert_false(ShopMenu.can_buy_one(_shop, ItemData.find(&"fixture_pebble")))
	(_sell_buttons(menu)[0] as Button).pressed.emit()
	assert_eq(Wallet.money, 8)
	assert_eq([pebble.disabled, service.disabled], [false, true], "a berry sold pays for a pebble")
	(_sell_buttons(menu)[0] as Button).pressed.emit()
	assert_eq([pebble.disabled, service.disabled, service.text], [false, false, "Polish — 10g"], "and the other for the service")
	service.grab_focus()
	assert_eq(menu.about_label.text, "Shines a blade.", "an offer tells of itself")
	pebble.pressed.emit()
	assert_eq(Wallet.money, 9)
	assert_true(service.disabled, "a purchase that leaves too little dims it again")
	menu.close()

func test_a_purchase_tells_how_many_are_left_today_and_dims_once_none_are() -> void:
	_shop.stock = {"fixture_pebble": 4}
	_shop.daily_limits = {"fixture_pebble": 2}
	Wallet.set_money(30)
	var menu := SHOP_MENU.instantiate() as ShopMenu
	add_child_autofree(menu)
	menu.open(_shop)
	var pebble := menu.items_container.get_child(0) as Button
	assert_eq(pebble.text, "Buy Pebble — 4g (2 left today)")
	menu.amount_button.pressed.emit()
	assert_eq(pebble.text, "Buy Pebble x5 — 20g (2 left today)")
	pebble.pressed.emit()
	assert_eq(InventoryState.get_quantity(&"fixture_pebble"), 3, "the two left of five")
	assert_eq([pebble.text, pebble.disabled], ["Buy Pebble x5 — 20g (0 left today)", true])
	menu.close()

static func _sell_buttons(menu: ShopMenu) -> Array:
	return menu.sell_container.get_children()

static func _focused(menu: ShopMenu) -> Control:
	return menu.get_viewport().gui_get_focus_owner()

static func _item(id: StringName, display_name: String, sell_price: int) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = display_name
	item.sell_price = sell_price
	return item

## An offer that costs 10g, which the counter may buy while the player
## affords it.
class FixtureOffer extends ShopOffer:
	func get_key() -> String:
		return "fixture_polish"

	func get_label(_context: Dictionary) -> String:
		return "Polish — %dg" % 10

	func describe(_context: Dictionary) -> String:
		return "Shines a blade."

	func can_buy(_context: Dictionary) -> bool:
		return Wallet.can_afford(10)

	func buy(_context: Dictionary) -> bool:
		return Wallet.spend(10)
