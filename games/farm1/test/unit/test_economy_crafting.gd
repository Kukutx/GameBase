extends GutTest

var _inventory_snapshot: Dictionary
var _inventory_max_slots: int
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _skill_snapshot: Dictionary
var _clock_snapshot: Dictionary

func before_each() -> void:
	_inventory_snapshot = InventoryState.to_save_data()
	_inventory_max_slots = InventoryState.max_slots
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_skill_snapshot = Skills.to_save_data()
	_clock_snapshot = WorldClock.to_save_data()
	InventoryState.clear()
	PlayerState.reset_new_game()
	Skills.reset_new_game()
	WorldClock.set_time(1, 8 * 60)

func after_each() -> void:
	InventoryState.max_slots = _inventory_max_slots
	InventoryState.load_save_data(_inventory_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	Skills.load_save_data(_skill_snapshot)
	WorldClock.load_save_data(_clock_snapshot)

func test_shop_buys_and_sells_using_shared_item_prices() -> void:
	var shop := load("res://game/data/shops/general_store.tres") as ShopData
	PlayerState.money = 100
	var bought := ShopState.buy(shop, &"turnip_seeds", 3)
	assert_eq(bought, 3)
	assert_eq(InventoryState.get_quantity(&"turnip_seeds"), 3)
	assert_eq(PlayerState.money, 40)

	InventoryState.add_item_by_id(&"berry", 2)
	var sold := ShopState.sell(&"berry", 1)
	assert_eq(sold, 1)
	assert_eq(PlayerState.money, 60)

func test_shop_buy_blocks_money_callback_reentrancy() -> void:
	var shop := ContentDB.get_shop(&"general_store")
	assert_not_null(shop)
	if shop == null:
		return
	PlayerState.money = 100
	var observed := {"entered": false, "inner_bought": -1}
	var reenter := func(_money: int) -> void:
		if bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_bought"] = ShopState.buy(shop, &"turnip_seeds", 1)
	PlayerState.money_changed.connect(reenter)
	assert_eq(ShopState.buy(shop, &"turnip_seeds", 1), 1)
	if PlayerState.money_changed.is_connected(reenter):
		PlayerState.money_changed.disconnect(reenter)
	assert_true(bool(observed["entered"]))
	assert_eq(int(observed["inner_bought"]), 0)
	assert_eq(PlayerState.money, 80)
	assert_eq(InventoryState.get_quantity(&"turnip_seeds"), 1)

func test_shop_sell_blocks_inventory_and_money_callback_reentrancy() -> void:
	InventoryState.add_item_by_id(&"berry", 3)
	PlayerState.money = 100
	var observed := {"removed_entered": false, "money_entered": false, "inner_removed": -1, "inner_money": -1}
	var remove_reenter := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"berry" or bool(observed["removed_entered"]):
			return
		observed["removed_entered"] = true
		observed["inner_removed"] = ShopState.sell(&"berry", 1)
	var money_reenter := func(_money: int) -> void:
		if bool(observed["money_entered"]):
			return
		observed["money_entered"] = true
		observed["inner_money"] = ShopState.sell(&"berry", 1)
	InventoryState.item_removed.connect(remove_reenter)
	PlayerState.money_changed.connect(money_reenter)
	assert_eq(ShopState.sell(&"berry", 1), 1)
	if InventoryState.item_removed.is_connected(remove_reenter):
		InventoryState.item_removed.disconnect(remove_reenter)
	if PlayerState.money_changed.is_connected(money_reenter):
		PlayerState.money_changed.disconnect(money_reenter)
	assert_true(bool(observed["removed_entered"]))
	assert_true(bool(observed["money_entered"]))
	assert_eq(int(observed["inner_removed"]), 0)
	assert_eq(int(observed["inner_money"]), 0)
	assert_eq(InventoryState.get_quantity(&"berry"), 2)
	assert_eq(PlayerState.money, 120)

func test_shop_purchase_refunds_money_if_inventory_changes_after_payment() -> void:
	var shop := ContentDB.get_shop(&"general_store")
	assert_not_null(shop)
	if shop == null:
		return
	InventoryState.max_slots = 1
	PlayerState.money = 100
	var observed := {"sabotaged": false, "purchases": 0}
	var sabotage := func(_money: int) -> void:
		if bool(observed["sabotaged"]):
			return
		observed["sabotaged"] = true
		InventoryState.add_item_by_id(&"gold_bar", 1)
	var on_purchase := func(_shop_id: StringName, _item_id: StringName, _quantity: int, _total: int) -> void:
		observed["purchases"] = int(observed["purchases"]) + 1
	PlayerState.money_changed.connect(sabotage)
	ShopState.purchase_completed.connect(on_purchase)

	assert_eq(ShopState.buy(shop, &"turnip_seeds", 1), 0)
	assert_eq(PlayerState.money, 100)
	assert_eq(InventoryState.get_quantity(&"turnip_seeds"), 0)
	assert_eq(InventoryState.get_quantity(&"gold_bar"), 1)
	assert_eq(int(observed["purchases"]), 0)

	if PlayerState.money_changed.is_connected(sabotage):
		PlayerState.money_changed.disconnect(sabotage)
	InventoryState.clear()
	assert_eq(ShopState.buy(shop, &"turnip_seeds", 1), 1)
	assert_eq(PlayerState.money, 80)
	assert_eq(InventoryState.get_quantity(&"turnip_seeds"), 1)
	assert_eq(int(observed["purchases"]), 1)
	if ShopState.purchase_completed.is_connected(on_purchase):
		ShopState.purchase_completed.disconnect(on_purchase)

func test_crafting_consumes_ingredients_and_creates_output() -> void:
	InventoryState.add_item_by_id(&"berry", 2)
	assert_true(CraftingState.craft(&"field_snack"))
	assert_eq(InventoryState.get_quantity(&"berry"), 0)
	assert_eq(InventoryState.get_quantity(&"field_snack"), 1)

func test_crafting_blocks_inventory_signal_reentrancy() -> void:
	InventoryState.add_item_by_id(&"berry", 4)
	var observed := {"entered": false, "inner_result": true}
	var reenter := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"berry" or bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_result"] = CraftingState.craft(&"field_snack")
	InventoryState.item_removed.connect(reenter)
	assert_true(CraftingState.craft(&"field_snack"))
	if InventoryState.item_removed.is_connected(reenter):
		InventoryState.item_removed.disconnect(reenter)
	assert_true(bool(observed["entered"]))
	assert_false(bool(observed["inner_result"]))
	assert_eq(InventoryState.get_quantity(&"berry"), 2)
	assert_eq(InventoryState.get_quantity(&"field_snack"), 1)

func test_crafting_reuses_consumed_ingredient_slot_when_inventory_is_full() -> void:
	InventoryState.max_slots = 1
	assert_eq(InventoryState.add_item_by_id(&"wood", 10), 0)
	assert_eq(InventoryState.get_used_slots(), 1)
	assert_eq(InventoryState.get_free_slots(), 0)
	assert_true(CraftingState.craft(&"storage_chest"))
	assert_eq(InventoryState.get_quantity(&"wood"), 0)
	assert_eq(InventoryState.get_quantity(&"storage_chest"), 1)
	assert_eq(InventoryState.get_used_slots(), 1)

func test_general_store_seasonal_seed_stock_changes_with_calendar() -> void:
	var shop := ContentDB.get_shop(&"general_store")
	assert_not_null(shop)
	var spring := shop.get_stock("Spring")
	var summer := shop.get_stock("Summer")
	var autumn := shop.get_stock("Autumn")
	var winter := shop.get_stock("Winter")
	assert_true(spring.has("turnip_seeds") and spring.has("carrot_seeds") and spring.has("potato_seeds"))
	assert_false(spring.has("tomato_seeds"))
	assert_true(summer.has("tomato_seeds"))
	assert_false(summer.has("turnip_seeds"))
	assert_true(autumn.has("pumpkin_seeds") and autumn.has("carrot_seeds"))
	assert_false(autumn.has("tomato_seeds"))
	assert_true(winter.has("frostroot_seeds"))
	assert_false(winter.has("pumpkin_seeds"))

	PlayerState.money = 500
	WorldClock.set_time(29, 8 * 60)
	assert_eq(WorldClock.get_season_name(), "Summer")
	assert_eq(ShopState.buy(shop, &"tomato_seeds", 1), 1)
	assert_eq(ShopState.buy(shop, &"turnip_seeds", 1), 0)

func test_metal_processing_never_reduces_shipping_value() -> void:
	for recipe_id: StringName in [&"smelt_copper_bar", &"smelt_iron_bar", &"smelt_gold_bar", &"smelt_iridium_bar"]:
		var recipe := ContentDB.get_processing_recipe(recipe_id)
		assert_not_null(recipe)
		if recipe == null:
			continue
		var input_value := 0
		for raw_id: Variant in recipe.inputs.keys():
			var item := ContentDB.get_item(StringName(String(raw_id)))
			assert_not_null(item)
			if item != null:
				input_value += item.sell_price * int(recipe.inputs[raw_id])
		var output := ContentDB.get_item(recipe.output_item_id)
		assert_not_null(output)
		if output != null:
			assert_gte(output.sell_price * recipe.output_quantity, input_value, "%s should not destroy shipping value" % recipe_id)
	assert_eq(ContentDB.get_item(&"iridium_bar").sell_price, 850)

func test_general_store_has_no_buy_sell_arbitrage() -> void:
	var shop := ContentDB.get_shop(&"general_store")
	assert_not_null(shop)
	if shop == null:
		return
	for season: String in GameClock.SEASON_NAMES:
		var stock := shop.get_stock(season)
		for raw_id: Variant in stock.keys():
			var item := ContentDB.get_item(StringName(String(raw_id)))
			assert_not_null(item)
			if item != null and item.sell_price > 0:
				assert_gte(int(stock[raw_id]), item.sell_price, "%s can be bought below its resale value in %s" % [raw_id, season])
