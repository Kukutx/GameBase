extends GutTest

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")

var _inventory_snapshot: Dictionary
var _inventory_max_slots: int
var _player_snapshot: Dictionary
var _vitals_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _clock_snapshot: Dictionary
var _world_snapshot: Dictionary
var _shop: ShopData

func before_each() -> void:
	_inventory_snapshot = InventoryState.to_save_data()
	_inventory_max_slots = InventoryState.max_slots
	_player_snapshot = Wallet.to_save_data()
	_vitals_snapshot = Vitals.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_clock_snapshot = WorldClock.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	WorldClock.set_time(1, 8 * 60)
	_shop = ShopData.new()
	_shop.id = &"fixture_store"
	_shop.display_name = "Store"
	_shop.stock = {"fixture_seeds": 20}
	_shop.seasonal_stock = {"Spring": {"fixture_spring_seeds": 25}, "Summer": {"fixture_summer_seeds": 30}}
	ContentFixture.use(self, [
		_shop,
		_item(&"fixture_seeds", 20, 10),
		_item(&"fixture_spring_seeds", 25, 12),
		_item(&"fixture_summer_seeds", 30, 15),
		_item(&"fixture_berry", 0, 20),
		_item(&"fixture_snack", 0, 50),
		_item(&"fixture_plank", 0, 5),
		_item(&"fixture_crate", 0, 0),
		_item(&"fixture_ingot", 0, 100),
		_recipe(&"fixture_snack", {"fixture_berry": 2}, &"fixture_snack"),
		_recipe(&"fixture_crate", {"fixture_plank": 10}, &"fixture_crate"),
	])
	InventoryState.clear()
	Wallet.reset_new_game()
	Vitals.reset_new_game()

func after_each() -> void:
	# GUT frees the fixture content after after_each(): restore the saved state
	# against the game's own content.
	ContentRegistry.active = ContentDB
	WorldClock.load_save_data(_clock_snapshot)
	WorldState.load_save_data(_world_snapshot)
	InventoryState.max_slots = _inventory_max_slots
	InventoryState.load_save_data(_inventory_snapshot)
	Wallet.load_save_data(_player_snapshot)
	Vitals.load_save_data(_vitals_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)

func test_shop_buys_and_sells_using_shared_item_prices() -> void:
	Wallet.money = 100
	var bought := ShopState.buy(_shop, &"fixture_seeds", 3)
	assert_eq(bought, 3)
	assert_eq(InventoryState.get_quantity(&"fixture_seeds"), 3)
	assert_eq(Wallet.money, 40)

	InventoryState.add_item_by_id(&"fixture_berry", 2)
	var sold := ShopState.sell(&"fixture_berry", 1)
	assert_eq(sold, 1)
	assert_eq(Wallet.money, 60)

func test_shop_buy_blocks_money_callback_reentrancy() -> void:
	Wallet.money = 100
	var observed := {"entered": false, "inner_bought": -1}
	var reenter := func(_money: int) -> void:
		if bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_bought"] = ShopState.buy(_shop, &"fixture_seeds", 1)
	Wallet.money_changed.connect(reenter)
	assert_eq(ShopState.buy(_shop, &"fixture_seeds", 1), 1)
	if Wallet.money_changed.is_connected(reenter):
		Wallet.money_changed.disconnect(reenter)
	assert_true(bool(observed["entered"]))
	assert_eq(int(observed["inner_bought"]), 0)
	assert_eq(Wallet.money, 80)
	assert_eq(InventoryState.get_quantity(&"fixture_seeds"), 1)

func test_shop_sell_blocks_inventory_and_money_callback_reentrancy() -> void:
	InventoryState.add_item_by_id(&"fixture_berry", 3)
	Wallet.money = 100
	var observed := {"removed_entered": false, "money_entered": false, "inner_removed": -1, "inner_money": -1}
	var remove_reenter := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"fixture_berry" or bool(observed["removed_entered"]):
			return
		observed["removed_entered"] = true
		observed["inner_removed"] = ShopState.sell(&"fixture_berry", 1)
	var money_reenter := func(_money: int) -> void:
		if bool(observed["money_entered"]):
			return
		observed["money_entered"] = true
		observed["inner_money"] = ShopState.sell(&"fixture_berry", 1)
	InventoryState.item_removed.connect(remove_reenter)
	Wallet.money_changed.connect(money_reenter)
	assert_eq(ShopState.sell(&"fixture_berry", 1), 1)
	if InventoryState.item_removed.is_connected(remove_reenter):
		InventoryState.item_removed.disconnect(remove_reenter)
	if Wallet.money_changed.is_connected(money_reenter):
		Wallet.money_changed.disconnect(money_reenter)
	assert_true(bool(observed["removed_entered"]))
	assert_true(bool(observed["money_entered"]))
	assert_eq(int(observed["inner_removed"]), 0)
	assert_eq(int(observed["inner_money"]), 0)
	assert_eq(InventoryState.get_quantity(&"fixture_berry"), 2)
	assert_eq(Wallet.money, 120)

func test_shop_purchase_refunds_money_if_inventory_changes_after_payment() -> void:
	InventoryState.max_slots = 1
	Wallet.money = 100
	var observed := {"sabotaged": false, "purchases": 0}
	var sabotage := func(_money: int) -> void:
		if bool(observed["sabotaged"]):
			return
		observed["sabotaged"] = true
		InventoryState.add_item_by_id(&"fixture_ingot", 1)
	var on_purchase := func(_shop_id: StringName, _item_id: StringName, _quantity: int, _total: int) -> void:
		observed["purchases"] = int(observed["purchases"]) + 1
	Wallet.money_changed.connect(sabotage)
	ShopState.purchase_completed.connect(on_purchase)

	assert_eq(ShopState.buy(_shop, &"fixture_seeds", 1), 0)
	assert_eq(Wallet.money, 100)
	assert_eq(InventoryState.get_quantity(&"fixture_seeds"), 0)
	assert_eq(InventoryState.get_quantity(&"fixture_ingot"), 1)
	assert_eq(int(observed["purchases"]), 0)

	if Wallet.money_changed.is_connected(sabotage):
		Wallet.money_changed.disconnect(sabotage)
	InventoryState.clear()
	assert_eq(ShopState.buy(_shop, &"fixture_seeds", 1), 1)
	assert_eq(Wallet.money, 80)
	assert_eq(InventoryState.get_quantity(&"fixture_seeds"), 1)
	assert_eq(int(observed["purchases"]), 1)
	if ShopState.purchase_completed.is_connected(on_purchase):
		ShopState.purchase_completed.disconnect(on_purchase)

func test_crafting_consumes_ingredients_and_creates_output() -> void:
	InventoryState.add_item_by_id(&"fixture_berry", 2)
	assert_true(CraftingState.craft(&"fixture_snack"))
	assert_eq(InventoryState.get_quantity(&"fixture_berry"), 0)
	assert_eq(InventoryState.get_quantity(&"fixture_snack"), 1)

func test_crafting_blocks_inventory_signal_reentrancy() -> void:
	InventoryState.add_item_by_id(&"fixture_berry", 4)
	var observed := {"entered": false, "inner_result": true}
	var reenter := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"fixture_berry" or bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_result"] = CraftingState.craft(&"fixture_snack")
	InventoryState.item_removed.connect(reenter)
	assert_true(CraftingState.craft(&"fixture_snack"))
	if InventoryState.item_removed.is_connected(reenter):
		InventoryState.item_removed.disconnect(reenter)
	assert_true(bool(observed["entered"]))
	assert_false(bool(observed["inner_result"]))
	assert_eq(InventoryState.get_quantity(&"fixture_berry"), 2)
	assert_eq(InventoryState.get_quantity(&"fixture_snack"), 1)

func test_crafting_reuses_consumed_ingredient_slot_when_inventory_is_full() -> void:
	InventoryState.max_slots = 1
	assert_eq(InventoryState.add_item_by_id(&"fixture_plank", 10), 0)
	assert_eq(InventoryState.get_used_slots(), 1)
	assert_eq(InventoryState.get_free_slots(), 0)
	assert_true(CraftingState.craft(&"fixture_crate"))
	assert_eq(InventoryState.get_quantity(&"fixture_plank"), 0)
	assert_eq(InventoryState.get_quantity(&"fixture_crate"), 1)
	assert_eq(InventoryState.get_used_slots(), 1)

func test_the_crafting_menu_says_what_a_locked_recipe_still_needs() -> void:
	var recipe := RecipeData.find(&"fixture_crate")
	recipe.condition = "MONEY_AT_LEAST %d" % (Wallet.money + 500)
	var menu := (load("res://tiamat/modules/items/crafting/crafting_menu.tscn") as PackedScene).instantiate() as CraftingMenu
	add_child_autofree(menu)
	menu.open()
	var texts := menu.recipes_container.get_children().map(func(button: Button) -> String: return button.text)
	assert_has(texts, "Fixture Crate  (Fixture Plank x10)\nNeeds: %dg" % (Wallet.money + 500))
	assert_has(texts, "Fixture Snack  (Fixture Berry x2)", "an open recipe names its ingredients alone")
	Wallet.add(500)
	menu.open()
	texts = menu.recipes_container.get_children().filter(func(child: Node) -> bool: return not child.is_queued_for_deletion()).map(func(button: Button) -> String: return button.text)
	assert_has(texts, "Fixture Crate  (Fixture Plank x10)", "once it holds, the recipe needs nothing more")
	menu.close()

func test_crafting_leaves_the_player_on_the_recipe_they_pressed() -> void:
	InventoryState.add_item_by_id(&"fixture_berry", 4)
	InventoryState.add_item_by_id(&"fixture_plank", 10)
	var menu := (load("res://tiamat/modules/items/crafting/crafting_menu.tscn") as PackedScene).instantiate() as CraftingMenu
	add_child_autofree(menu)
	menu.open()
	var snack := _recipe_button(menu, "Fixture Snack")
	assert_ne(_recipe_button(menu, "Fixture Crate"), null)
	snack.grab_focus()
	snack.pressed.emit()
	assert_eq(InventoryState.get_quantity(&"fixture_snack"), 1)
	var focused := get_viewport().gui_get_focus_owner() as Button
	assert_eq(focused, _recipe_button(menu, "Fixture Snack"), "the rebuilt list keeps the focus on the snack")
	assert_false(focused.disabled, "two berries make one more")
	focused.pressed.emit()
	focused = get_viewport().gui_get_focus_owner() as Button
	assert_eq(focused, _recipe_button(menu, "Fixture Crate"), "with the berries spent, the nearest recipe still open")
	menu.close()

# The button of the recipe whose text begins with `name` in `menu`'s list, the
# one the list shows now.
func _recipe_button(menu: CraftingMenu, name: String) -> Button:
	for child: Node in menu.recipes_container.get_children():
		if not child.is_queued_for_deletion() and (child as Button).text.begins_with(name):
			return child as Button
	return null

func test_seasonal_stock_changes_with_calendar() -> void:
	ContentFixture.use_calendar(self, GameCalendar.new())
	var spring := _shop.get_stock("Spring")
	var summer := _shop.get_stock("Summer")
	assert_true(spring.has("fixture_seeds") and spring.has("fixture_spring_seeds"))
	assert_false(spring.has("fixture_summer_seeds"))
	assert_true(summer.has("fixture_seeds") and summer.has("fixture_summer_seeds"))
	assert_false(summer.has("fixture_spring_seeds"))
	assert_eq(_shop.get_stock("Winter"), {"fixture_seeds": 20}, "a season without its own stock sells the year-round stock")

	Wallet.money = 500
	assert_eq(ShopState.buy(_shop, &"fixture_spring_seeds", 1), 1)
	WorldClock.set_time(29, 8 * 60)
	assert_eq(WorldClock.get_season_name(), "Summer")
	assert_eq(ShopState.buy(_shop, &"fixture_summer_seeds", 1), 1)
	assert_eq(ShopState.buy(_shop, &"fixture_spring_seeds", 1), 0)
	assert_eq(ShopState.buy(_shop, &"fixture_seeds", 1), 1)

func test_a_listing_is_sold_only_while_its_condition_holds() -> void:
	var listing := ShopListing.new()
	listing.item_id = &"fixture_ingot"
	listing.price = 120
	listing.condition = "DAY_AT_LEAST 3"
	_shop.listings.append(listing)
	Wallet.money = 500
	assert_false(_shop.has_item(&"fixture_ingot"), "not on day 1")
	assert_eq(ShopState.buy(_shop, &"fixture_ingot", 1), 0)
	assert_eq(ItemSources.gather().get_ways(&"fixture_ingot"), PackedStringArray(["Sold at Store (From day 3)"]), "where, and once what")
	WorldClock.set_time(3, 8 * 60)
	assert_true(_shop.has_item(&"fixture_ingot"))
	assert_eq(_shop.get_buy_price(ItemData.find(&"fixture_ingot")), 120, "at the listing's price")
	assert_eq(ShopState.buy(_shop, &"fixture_ingot", 1), 1)
	listing.condition = ""
	assert_eq(ItemSources.gather().get_ways(&"fixture_ingot"), PackedStringArray(["Sold at Store"]), "a listing open always reads as the stock")

func test_a_shop_sells_so_many_of_an_item_a_day() -> void:
	_shop.daily_limits = {"fixture_seeds": 3}
	Wallet.money = 500
	assert_eq(ShopState.get_left_today(_shop, &"fixture_seeds"), 3)
	assert_eq(ShopState.get_left_today(_shop, &"fixture_spring_seeds"), -1, "an item it does not limit")
	assert_eq(ShopState.buy(_shop, &"fixture_seeds", 2), 2)
	assert_eq(ShopState.get_left_today(_shop, &"fixture_seeds"), 1)
	assert_eq(ShopState.buy(_shop, &"fixture_seeds", 5), 1, "what is left of the day's")
	assert_eq(Wallet.money, 500 - 3 * 20)
	watch_signals(GameEvents)
	assert_eq(ShopState.buy(_shop, &"fixture_seeds", 1), 0)
	assert_signal_emitted_with_parameters(GameEvents, "toast_requested", ["Sold out for today"])
	assert_eq(Wallet.money, 500 - 3 * 20, "and costs nothing")
	var saved: Variant = JSON.parse_string(JSON.stringify(WorldState.to_save_data()))
	WorldState.clear()
	WorldState.load_save_data(saved)
	assert_eq(ShopState.get_left_today(_shop, &"fixture_seeds"), 0, "a save keeps the day's count")
	WorldClock.set_time(2, 8 * 60)
	assert_eq(ShopState.get_left_today(_shop, &"fixture_seeds"), 3, "a new day brings the full count back")
	assert_eq(ShopState.buy(_shop, &"fixture_seeds", 1), 1)

func test_what_is_wrong_with_a_shop_s_listings() -> void:
	_shop.seasonal_stock = {}
	var free := ShopListing.new()
	free.item_id = &"fixture_ingot"
	var twice := ShopListing.new()
	twice.item_id = &"fixture_ingot"
	twice.price = 5
	var unknown := ShopListing.new()
	unknown.item_id = &"fixture_nothing"
	unknown.price = 5
	unknown.condition = "NO_SUCH_CONDITION"
	_shop.listings.assign([free, twice, null, unknown])
	assert_eq(_shop.find_problems(ContentRegistry.active), PackedStringArray([
		"lists 'fixture_ingot' twice",
		"has an empty listing",
		"leaves the listing price of 'fixture_ingot' to the item, which has no buy_price",
		"lists unknown item 'fixture_nothing'",
	]))
	_shop.listings.clear()
	_shop.daily_limits = {"fixture_ingot": 0, "fixture_nothing": 1, "fixture_berry": 2, "fixture_seeds": 4}
	assert_eq(_shop.find_problems(ContentRegistry.active), PackedStringArray([
		"has an invalid daily limit for 'fixture_ingot'",
		"limits unknown item 'fixture_nothing'",
		"limits 'fixture_berry', which it never sells",
	]), "a limit of what it stocks is fine")
	_shop.listings.assign([free, twice, null, unknown])
	var problems := GameRules.validate_content(ContentRegistry.active)
	assert_true(Array(problems).any(func(problem: String) -> bool: return problem.contains("fixture_store") and problem.contains("NO_SUCH_CONDITION")), "the content check reads a listing's condition: %s" % [problems])

func _item(id: StringName, buy_price: int, sell_price: int) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	item.buy_price = buy_price
	item.sell_price = sell_price
	return item

func _recipe(id: StringName, ingredients: Dictionary, output_item_id: StringName) -> RecipeData:
	var recipe := RecipeData.new()
	recipe.id = id
	recipe.display_name = String(id).capitalize()
	recipe.ingredients = ingredients
	recipe.output_item_id = output_item_id
	return recipe
