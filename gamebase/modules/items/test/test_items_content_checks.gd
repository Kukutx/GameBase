extends GutTest

## The checks the items module's kinds of content make of themselves, on
## broken entries the test builds.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

func after_each() -> void:
	# GUT frees the fixture after this; restore against the game's content.
	ContentRegistry.active = ContentDB

func test_the_items_module_registers_its_kinds_of_content() -> void:
	for kind: StringName in [ItemData.KIND, FoodBuffData.KIND, PlaceableData.KIND, RecipeData.KIND, ShopData.KIND]:
		assert_true(ContentDB.get_kinds().has(kind), "the items module registers kind '%s'" % kind)

func test_unknown_item_ids_return_null() -> void:
	var berry := _item(&"fixture_berry")
	ContentFixture.use(self, [berry])
	assert_eq(ItemData.find(&"fixture_berry"), berry)
	assert_null(ItemData.find(&"fixture_missing"))

func test_items_report_unhandled_tool_actions_stacked_tools_and_stray_crops() -> void:
	var bad_tool := _item(&"fixture_bad_tool")
	bad_tool.kind = ItemData.Kind.TOOL
	bad_tool.tool_action = &"fixture_unhandled_action"
	bad_tool.max_stack = 2
	var bad_material := _item(&"fixture_bad_material")
	bad_material.crop_id = &"fixture_crop"
	var entries: Array = [bad_tool, bad_material]
	var joined := _problems_of(ContentFixture.use(self, entries), entries)
	assert_string_contains(joined, "item 'fixture_bad_tool' is a tool with action 'fixture_unhandled_action', which no installed module or the game handles")
	assert_string_contains(joined, "item 'fixture_bad_tool' is a tool and must have max_stack 1")
	assert_string_contains(joined, "item 'fixture_bad_material' is not a seed but names crop 'fixture_crop'")

func test_food_buffs_report_unread_stats_and_non_positive_multipliers() -> void:
	ContentFixture.add_stat(self, &"fixture_speed")
	var bad_buff := FoodBuffData.new()
	bad_buff.id = &"fixture_bad_buff"
	bad_buff.multipliers = {&"fixture_typo_speed": 1.2, &"fixture_speed": 0.0}
	var entries: Array = [bad_buff]
	var joined := _problems_of(ContentFixture.use(self, entries), entries)
	assert_string_contains(joined, "food buff 'fixture_bad_buff' changes stat 'fixture_typo_speed', which no installed module or the game reads")
	assert_string_contains(joined, "food buff 'fixture_bad_buff' has a non-positive multiplier of 'fixture_speed'")

func test_shops_and_recipes_report_malformed_numbers_without_crashing() -> void:
	ContentFixture.use_calendar(self, GameCalendar.new())
	var berry := _item(&"fixture_berry")
	var shop := ShopData.new()
	shop.id = &"fixture_bad_shop"
	shop.stock = {"fixture_berry": "not-a-price"}
	shop.seasonal_stock = {"Spring": {"fixture_berry": {"bad": true}}}
	var recipe := RecipeData.new()
	recipe.id = &"fixture_bad_recipe"
	recipe.display_name = "Bad Recipe"
	recipe.ingredients = {"fixture_berry": {"bad": true}}
	recipe.output_item_id = &"fixture_berry"
	recipe.output_quantity = 0
	var entries: Array = [berry, shop, recipe]
	var joined := _problems_of(ContentFixture.use(self, entries), entries)
	assert_string_contains(joined, "shop 'fixture_bad_shop' has invalid price for 'fixture_berry'")
	assert_string_contains(joined, "shop 'fixture_bad_shop' has invalid Spring price for 'fixture_berry'")
	assert_string_contains(joined, "recipe 'fixture_bad_recipe' has invalid ingredient quantity for 'fixture_berry'")
	assert_string_contains(joined, "recipe 'fixture_bad_recipe' has invalid output quantity 0")

func test_a_shop_stand_reports_a_shop_the_content_does_not_hold() -> void:
	var shop := ShopData.new()
	shop.id = &"fixture_shop"
	var registry := ContentFixture.use(self, [shop])
	var root := Node2D.new()
	autofree(root)
	var stand := ShopStand.new()
	stand.name = "GoodShop"
	stand.shop = shop
	root.add_child(stand)
	var bad_stand := ShopStand.new()
	bad_stand.name = "BadShop"
	bad_stand.shop = ShopData.new()
	bad_stand.shop.id = &"fixture_unregistered_shop"
	root.add_child(bad_stand)
	assert_eq(registry.find_scene_problems(root, null), PackedStringArray(["shop stand 'BadShop' references an unregistered shop"]))

func _item(id: StringName) -> ItemData:
	var item := ItemData.new()
	item.id = id
	return item

func _problems_of(registry: ContentRegistry, entries: Array) -> String:
	var problems := PackedStringArray()
	for entry: ContentEntry in entries:
		problems.append_array(registry.find_entry_problems(entry))
	return "\n".join(problems)
