extends GutTest

## The items module's menus, the crafting station, a shop's counter and a
## storage chest, each opened on content of the test's own, full and empty:
## the focus starts in the menu on a control that works, and every control
## fits the view, a long list scrolling within it.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const MenuFit := preload("res://gamebase/core/test/menu_fit.gd")
const CRAFTING_MENU := preload("res://gamebase/modules/items/crafting/crafting_menu.tscn")
const SHOP_MENU := preload("res://gamebase/modules/items/shop/shop_menu.tscn")
const STORAGE_MENU := preload("res://gamebase/modules/items/storage/storage_menu.tscn")
## More entries than any of the menus shows at once.
const ENTRY_COUNT := 14
const CHEST := &"fixture_menu_chest"

var _world_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _wallet_snapshot: Dictionary
var _vitals_snapshot: Dictionary

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_wallet_snapshot = Wallet.to_save_data()
	_vitals_snapshot = Vitals.to_save_data()
	InventoryState.clear()
	Wallet.reset_new_game()
	Vitals.reset_new_game()

func after_each() -> void:
	# GUT frees the fixture content only after this hook.
	ContentRegistry.active = ContentDB
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	Wallet.load_save_data(_wallet_snapshot)
	Vitals.load_save_data(_vitals_snapshot)
	InputLock.clear()

func test_each_menu_holds_the_focus_and_fits_the_view_with_a_long_list() -> void:
	var items := _items()
	var shop := ShopData.new()
	shop.id = &"fixture_menu_shop"
	shop.display_name = "The Fixture Emporium of Uncommonly Long Names"
	var recipes: Array = []
	for item: ItemData in items:
		shop.stock[String(item.id)] = 1
		recipes.append(_recipe(item))
	ContentFixture.use(self, items + recipes + [shop])
	Wallet.money = 999999
	for item: ItemData in items:
		InventoryState.add_item(item, 3)
	StorageState.store_item(CHEST, items[0].id, 1)
	await _check(CRAFTING_MENU, func(menu: Node) -> void: menu.call("open"))
	await _check(SHOP_MENU, func(menu: Node) -> void: menu.call("open", shop))
	await _check(STORAGE_MENU, func(menu: Node) -> void: menu.call("open", CHEST, "Chest", 24))

func test_each_menu_holds_the_focus_and_fits_the_view_with_nothing_to_show() -> void:
	var shop := ShopData.new()
	shop.id = &"fixture_menu_shop"
	ContentFixture.use(self, [shop])
	await _check(CRAFTING_MENU, func(menu: Node) -> void: menu.call("open"))
	await _check(SHOP_MENU, func(menu: Node) -> void: menu.call("open", shop))
	await _check(STORAGE_MENU, func(menu: Node) -> void: menu.call("open", CHEST, "Chest", 24))

# Opens a menu of `scene` with `open`, and checks its focus and its fit.
func _check(scene: PackedScene, open: Callable) -> void:
	var menu := scene.instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame
	open.call(menu)
	await get_tree().process_frame
	assert_eq(MenuFit.find_focus_problem(menu), "", scene.resource_path)
	# Containers sort their children on the frame after a change.
	await get_tree().process_frame
	assert_eq(MenuFit.find_overflow(menu, get_viewport().get_visible_rect()), PackedStringArray(), scene.resource_path)
	menu.call("close")
	await get_tree().process_frame

static func _items() -> Array:
	var items: Array = []
	for index: int in ENTRY_COUNT:
		var item := ItemData.new()
		item.id = StringName("fixture_menu_item_%02d" % index)
		item.display_name = "Fixture Item With A Rather Long Name %02d" % index
		item.buy_price = 10
		item.sell_price = 5
		items.append(item)
	return items

# A recipe that makes `item` out of itself, which the inventory can afford.
static func _recipe(item: ItemData) -> RecipeData:
	var recipe := RecipeData.new()
	recipe.id = StringName("%s_recipe" % item.id)
	recipe.display_name = item.display_name
	recipe.ingredients = {String(item.id): 1}
	recipe.output_item_id = item.id
	return recipe
