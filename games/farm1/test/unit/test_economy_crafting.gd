extends GutTest

# Farm1's shop stock and prices. How shops and crafting work is tested on
# fixture content in gamebase/modules/items/test/test_economy_crafting.gd.

var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _skill_snapshot: Dictionary
var _clock_snapshot: Dictionary
var _world_snapshot: Dictionary
var _quest_snapshot: Dictionary

func before_each() -> void:
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_skill_snapshot = Skills.to_save_data()
	_clock_snapshot = WorldClock.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	_quest_snapshot = QuestState.to_save_data()
	InventoryState.clear()
	PlayerState.reset_new_game()
	Skills.reset_new_game()
	QuestState.load_save_data({})
	WorldClock.set_time(1, 8 * 60)

func after_each() -> void:
	InventoryState.load_save_data(_inventory_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	Skills.load_save_data(_skill_snapshot)
	WorldClock.load_save_data(_clock_snapshot)
	WorldState.load_save_data(_world_snapshot)
	QuestState.load_save_data(_quest_snapshot)

func test_general_store_sells_turnip_seeds_for_20g_and_buys_berries_for_20g() -> void:
	var shop := ShopData.find(&"general_store")
	PlayerState.money = 100
	assert_eq(ShopState.buy(shop, &"turnip_seeds", 3), 3)
	assert_eq(PlayerState.money, 40)
	InventoryState.add_item_by_id(&"berry", 2)
	assert_eq(ShopState.sell(&"berry", 1), 1)
	assert_eq(PlayerState.money, 60)

func test_a_field_snack_is_made_from_two_berries() -> void:
	InventoryState.add_item_by_id(&"berry", 2)
	assert_true(CraftingState.craft(&"field_snack"))
	assert_eq(InventoryState.get_quantity(&"berry"), 0)
	assert_eq(InventoryState.get_quantity(&"field_snack"), 1)

func test_general_store_seasonal_seed_stock_changes_with_calendar() -> void:
	var shop := ShopData.find(&"general_store")
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

func test_metal_processing_never_reduces_shipping_value() -> void:
	for recipe_id: StringName in [&"smelt_copper_bar", &"smelt_iron_bar", &"smelt_gold_bar", &"smelt_iridium_bar"]:
		var recipe := ProcessingRecipeData.find(recipe_id)
		assert_not_null(recipe)
		if recipe == null:
			continue
		var input_value := 0
		for raw_id: Variant in recipe.inputs.keys():
			var item := ItemData.find(StringName(String(raw_id)))
			assert_not_null(item)
			if item != null:
				input_value += item.sell_price * int(recipe.inputs[raw_id])
		var output := ItemData.find(recipe.output_item_id)
		assert_not_null(output)
		if output != null:
			assert_gte(output.sell_price * recipe.output_quantity, input_value, "%s should not destroy shipping value" % recipe_id)
	assert_eq(ItemData.find(&"iridium_bar").sell_price, 850)

func test_general_store_has_no_buy_sell_arbitrage() -> void:
	var shop := ShopData.find(&"general_store")
	assert_not_null(shop)
	if shop == null:
		return
	for season: String in GameClock.SEASON_NAMES:
		var stock := shop.get_stock(season)
		for raw_id: Variant in stock.keys():
			var item := ItemData.find(StringName(String(raw_id)))
			assert_not_null(item)
			if item != null and item.sell_price > 0:
				assert_gte(int(stock[raw_id]), item.sell_price, "%s can be bought below its resale value in %s" % [raw_id, season])
