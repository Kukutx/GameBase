extends GutTest

## A shop's counter (`ShopMenu`): its sell list follows the inventory in
## place, and the focus stays on the list as stacks sell out.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const SHOP_MENU := preload("res://gamebase/modules/items/shop/shop_menu.tscn")

var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _shop: ShopData

func before_each() -> void:
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_shop = ShopData.new()
	_shop.id = &"fixture_counter"
	_shop.display_name = "Counter"
	ContentFixture.use(self, [_item(&"fixture_berry", "Berry", 5), _item(&"fixture_pebble", "Pebble", 3), _shop])
	InventoryState.clear()
	PlayerState.reset_new_game()
	InventoryState.add_item_by_id(&"fixture_berry", 2)
	InventoryState.add_item_by_id(&"fixture_pebble", 1)

func after_each() -> void:
	# GUT frees the fixture content only after this hook.
	ContentRegistry.active = ContentDB
	InventoryState.load_save_data(_inventory_snapshot)
	PlayerState.load_save_data(_player_snapshot)

func test_selling_keeps_the_buttons_in_place_and_the_focus_on_the_list() -> void:
	var money := PlayerState.money
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
	assert_eq(PlayerState.money, money + 2 * 5 + 3)
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
