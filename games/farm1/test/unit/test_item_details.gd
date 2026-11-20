extends GutTest

## Farm1's inventory tab: the item chosen to bind to the hotbar shows what it
## is, what it does and every way to get more (`ItemSources`).

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
	_choose(item_select, &"copper_ore")
	assert_string_contains(content.text, "[b]Copper Ore[/b]\nRaw copper ore from mineral veins.")
	assert_string_contains(content.text, "Where to get: Sold at Village General Store (Complete Riverside Workshop Fund); Mined from Copper Vein", "the store's once the workshop is funded")
	assert_false(content.text.contains("Restores"), "ore does nothing")
	assert_eq(String(item_select.get_item_metadata(item_select.selected)), "copper_ore", "the choice stays as the tab refreshes")
	menu.call("close")

func test_the_inventory_tells_what_a_dish_restores_and_how_hard_a_blade_hits() -> void:
	for item_id: StringName in [&"fire_roasted_tomatoes", &"rusty_sword", &"copper_sword"]:
		InventoryState.add_item_by_id(item_id)
	var menu := (load("res://game/ui/game_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(menu)
	menu.call("open")
	var item_select := menu.get("item_select") as OptionButton
	var content := menu.get("content") as RichTextLabel
	_choose(item_select, &"fire_roasted_tomatoes")
	assert_string_contains(content.text, "Restores 20 Energy, 25 Health · Gives Fiery Belly (Burn chance +20)")
	_choose(item_select, &"copper_sword")
	var copper := ItemData.find(&"copper_sword")
	var gap := WeaponUse.damage_of(copper) - WeaponUse.damage_of(ItemData.find(&"rusty_sword"))
	assert_gt(gap, 0)
	assert_string_contains(content.text, "Attack %d (+%d vs. your Rusty Sword)" % [WeaponUse.damage_of(copper), gap], "beside the blade it would replace")
	menu.call("close")

# Picks `item_id` in the list of items to bind, as the player does.
func _choose(item_select: OptionButton, item_id: StringName) -> void:
	var index := -1
	for option: int in item_select.item_count:
		if StringName(String(item_select.get_item_metadata(option))) == item_id:
			index = option
	assert_gt(index, -1, "%s is in the list to bind" % item_id)
	item_select.select(index)
	item_select.item_selected.emit(index)
