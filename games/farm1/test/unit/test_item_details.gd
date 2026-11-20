extends GutTest

## Farm1's inventory tab: the item chosen to bind to the hotbar shows what it
## is and every way to get more (`ItemSources`).

var _inventory_snapshot: Dictionary

func before_each() -> void:
	_inventory_snapshot = InventoryState.to_save_data()
	InventoryState.clear()

func after_each() -> void:
	InventoryState.load_save_data(_inventory_snapshot)
	InputLock.clear()

func test_the_inventory_tells_what_an_item_is_and_where_to_get_more() -> void:
	InventoryState.add_item_by_id(&"wood", 3)
	InventoryState.add_item_by_id(&"copper_ore", 2)
	var menu := (load("res://game/ui/game_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(menu)
	menu.call("open")
	var item_select := menu.get("item_select") as OptionButton
	var content := menu.get("content") as RichTextLabel
	var index := -1
	for option: int in item_select.item_count:
		if String(item_select.get_item_metadata(option)) == "copper_ore":
			index = option
	assert_gt(index, -1, "the ore is in the list to bind")
	item_select.select(index)
	item_select.item_selected.emit(index)
	assert_string_contains(content.text, "[b]Copper Ore[/b]\nRaw copper ore from mineral veins.")
	assert_string_contains(content.text, "Where to get: Mined from Copper Vein")
	assert_eq(String(item_select.get_item_metadata(item_select.selected)), "copper_ore", "the choice stays as the tab refreshes")
	menu.call("close")
