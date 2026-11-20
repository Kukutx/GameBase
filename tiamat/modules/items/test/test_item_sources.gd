extends GutTest

## Where the player gets each item (`ItemSources`): the ways the items module
## finds, a way a game adds of its own, and that every item of the game the
## test runs in can be got.

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")
const CRAFTING_MENU := preload("res://tiamat/modules/items/crafting/crafting_menu.tscn")

var _inventory_snapshot: Dictionary

func before_each() -> void:
	_inventory_snapshot = InventoryState.to_save_data()
	InventoryState.clear()

func after_each() -> void:
	InventoryState.load_save_data(_inventory_snapshot)
	InputLock.clear()
	ItemSources._finders.erase(&"fixture")
	# GUT frees the fixture after this; restore against the game's content.
	ContentRegistry.active = ContentDB

func test_a_shop_a_recipe_and_a_reward_are_ways_to_get_an_item() -> void:
	var berry := _item(&"fixture_berry", "Berry")
	var pie := _item(&"fixture_pie", "Pie")
	var sword := _item(&"fixture_sword", "Sword")
	var medal := _item(&"fixture_medal", "Medal")
	var lost := _item(&"fixture_lost", "Lost")
	var shop := ShopData.new()
	shop.id = &"fixture_shop"
	shop.display_name = "Corner Shop"
	shop.stock = {"fixture_sword": 40}
	shop.seasonal_stock = {"Summer": {"fixture_berry": 5}}
	var recipe := RecipeData.new()
	recipe.id = &"fixture_pie_recipe"
	recipe.display_name = "Pie"
	recipe.category = RecipeData.Category.COOKING
	recipe.ingredients = {"fixture_berry": 3, "fixture_sword": 1}
	recipe.output_item_id = &"fixture_pie"
	var trigger := TriggerData.new()
	trigger.id = &"fixture_medal_trigger"
	trigger.event = &"GameSession.new_game_started"
	trigger.actions = PackedStringArray(["ADD_MONEY 5, ADD_ITEM fixture_medal 1"])
	var registry := ContentFixture.use(self, [berry, pie, sword, medal, lost, shop, recipe, trigger])
	var sources := ItemSources.gather(registry)
	assert_eq(sources.get_ways(&"fixture_sword"), PackedStringArray(["Sold at Corner Shop"]))
	assert_eq(sources.get_ways(&"fixture_berry"), PackedStringArray(["Sold at Corner Shop"]), "in its season, and listed once")
	assert_eq(sources.get_ways(&"fixture_pie"), PackedStringArray(["Cooked from Berry x3, Sword"]))
	assert_eq(sources.get_ways(&"fixture_medal"), PackedStringArray(["Given as a reward"]), "an action of any content")
	assert_eq(sources.find_unobtainable(registry), PackedStringArray(["fixture_lost"]))
	assert_eq(ItemSources.describe(&"fixture_pie"), sources.get_ways(&"fixture_pie"), "the running game's content")

func test_a_game_adds_a_way_of_its_own() -> void:
	var lost := _item(&"fixture_lost", "Lost")
	var registry := ContentFixture.use(self, [lost])
	ItemSources.register(&"fixture", func(_registry: ContentRegistry, sources: ItemSources) -> void:
		sources.add(&"fixture_lost", "Found in a chest"))
	ItemSources.register(&"fixture", func(_registry: ContentRegistry, sources: ItemSources) -> void:
		sources.add(&"fixture_lost", "Found under the bridge")
		sources.add(&"fixture_lost", "Found under the bridge"))
	assert_eq(ItemSources.gather(registry).get_ways(&"fixture_lost"), PackedStringArray(["Found under the bridge"]),
		"registering again replaces the finder, and a way is listed once")
	assert_eq(ItemSources.gather(registry).find_unobtainable(registry), PackedStringArray())

func test_the_crafting_menu_says_where_to_get_what_a_recipe_lacks() -> void:
	var ore := _item(&"fixture_ore", "Ore")
	var coal := _item(&"fixture_coal", "Coal")
	var bar := _item(&"fixture_bar", "Bar")
	var shop := ShopData.new()
	shop.id = &"fixture_shop"
	shop.display_name = "Smithy"
	shop.stock = {"fixture_ore": 10, "fixture_coal": 5}
	var recipe := RecipeData.new()
	recipe.id = &"fixture_bar_recipe"
	recipe.display_name = "Bar"
	recipe.ingredients = {"fixture_ore": 2, "fixture_coal": 1}
	recipe.output_item_id = bar.id
	ContentFixture.use(self, [ore, coal, bar, shop, recipe])
	InventoryState.add_item(ore, 1)
	InventoryState.add_item(coal, 1)
	var menu := CRAFTING_MENU.instantiate() as CraftingMenu
	add_child_autofree(menu)
	menu.open()
	var button := menu.recipes_container.get_child(0) as Button
	assert_eq(button.text, "Bar  (Ore x2, Coal x1)\nOre: Sold at Smithy", "what the player lacks, not what they have")
	assert_true(button.disabled)
	menu.close()

func test_the_pause_menu_s_items_tell_what_the_player_carries_and_where_to_get_more() -> void:
	var ore := _item(&"fixture_ore", "Ore")
	ore.description = "Raw ore."
	var shop := ShopData.new()
	shop.id = &"fixture_shop"
	shop.display_name = "Smithy"
	shop.stock = {"fixture_ore": 10}
	ContentFixture.use(self, [ore, shop])
	assert_eq(ItemsModule.describe_carried(), PackedStringArray(), "nothing while the player carries nothing")
	InventoryState.add_item(ore, 2)
	assert_eq(ItemsModule.describe_carried(), PackedStringArray(["Money: %s" % Wallet.describe(), "Ore x2", "  Raw ore.", "  Where to get: Sold at Smithy"]))
	assert_true(PauseMenu.get_page_ids().has(&"items"))

func test_every_item_of_the_game_can_be_got() -> void:
	assert_eq(ItemSources.gather().find_unobtainable(ContentDB), PackedStringArray(),
		"an item the player has no way to get: sell it, craft it, drop it, reward it, or register the game's own way (ItemSources.register())")

func _item(id: StringName, display_name: String) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = display_name
	return item
