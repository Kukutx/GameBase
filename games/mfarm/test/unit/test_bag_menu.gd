extends GutTest

## MFarm's bags on screen (`MFarmBagMenu`) fit each view the game is laid out
## in, a phone's smaller one among them: the action bar along the bottom, the
## player's bag, a shop's stock beside it and the trade panel over them.

const MenuFit := preload("res://tiamat/core/test/menu_fit.gd")
const SHOP := &"shop:fit_test"

var _state: Dictionary

func before_each() -> void:
	_state = WorldState.to_save_data()
	WorldState.clear()

func after_each() -> void:
	InputLock.clear()
	WorldState.load_save_data(_state)

func test_the_bags_and_the_trade_fit_each_view() -> void:
	var menu := MFarmBagMenu.new()
	add_child_autofree(menu)
	await get_tree().process_frame
	assert_eq(await MenuFit.find_overflow_in_views(menu), PackedStringArray(), "the action bar")
	menu.toggle_bag()
	await get_tree().process_frame
	assert_eq(await MenuFit.find_overflow_in_views(menu), PackedStringArray(), "the player's bag")
	menu.open_shop(SHOP, &"koyo_shop")
	await get_tree().process_frame
	assert_eq(menu.get_open_bag(), SHOP)
	assert_eq(await MenuFit.find_overflow_in_views(menu), PackedStringArray(), "beside a shop's stock")
	var trade := menu.get("_trade") as MFarmTradePanel
	trade.open_trade(SHOP, 0, false)
	await get_tree().process_frame
	assert_true(trade.visible, "the trade asks how many")
	assert_eq(await MenuFit.find_overflow_in_views(menu), PackedStringArray(), "and the trade over them")
	menu.close()
