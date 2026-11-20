extends GutTest

## MFarm's bags on screen (`MFarmBagMenu`) fit each view the game is laid out
## in, a phone's smaller one among them: the action bar along the bottom, the
## player's bag, a shop's stock beside it and the trade panel over them; and
## the close tag of a shop's bag names the device's own way to close it.

const MenuFit := preload("res://tiamat/core/test/menu_fit.gd")
const SHOP := &"shop:fit_test"

var _state: Dictionary

func before_each() -> void:
	_state = WorldState.to_save_data()
	WorldState.clear()

func after_each() -> void:
	InputPrompts.call("_set_using_touch", false)
	InputPrompts.call("_set_using_gamepad", false)
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

func test_the_close_tag_names_the_device_s_way_to_close() -> void:
	var menu := MFarmBagMenu.new()
	add_child_autofree(menu)
	await get_tree().process_frame
	menu.open_shop(SHOP, &"koyo_shop")
	var tag := menu.get("_escape_label") as Label
	assert_eq(tag.text, "ESC", "the old game's on a keyboard")
	InputPrompts.call("_set_using_touch", true)
	assert_eq(tag.text, "×", "the close button's on touch")
	InputPrompts.call("_set_using_gamepad", true)
	assert_eq(tag.text, InputPrompts.get_action_prompt(&"ui_cancel"), "the pad's back button")
	assert_ne(tag.text, "ESC")
	menu.close()
