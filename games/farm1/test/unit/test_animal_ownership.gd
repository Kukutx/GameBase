extends GutTest

# Farm1's animals, its general store and the animals of its dev world. How
# animals are owned, housed, fed and sold is tested on fixture content in
# gamebase/modules/lifesim/test/test_animal_ownership.gd.

var _world_snapshot: Dictionary
var _player_snapshot: Dictionary
var _vitals_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _clock_day: int
var _clock_minute: int

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_player_snapshot = Wallet.to_save_data()
	_vitals_snapshot = Vitals.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_clock_day = WorldClock.day
	_clock_minute = WorldClock.minute_of_day
	WorldState.clear()
	InventoryState.clear()
	Wallet.reset_new_game()
	Vitals.reset_new_game()
	Wallet.money = 10000
	WorldClock.set_time(1, 8 * 60)
	AnimalState.register_housing(&"starter_coop", &"starter_town", &"coop", 4, "Coop")
	AnimalState.register_housing(&"starter_barn", &"starter_town", &"barn", 4, "Barn")
	AnimalState.reset_new_game()
	AnimalState.grant_animal(&"starter_chicken_01", &"chicken", &"starter_town", &"starter_coop", 0)
	AnimalState.grant_animal(&"starter_cow_01", &"cow", &"starter_town", &"starter_barn", 0)

func after_each() -> void:
	AnimalState.unregister_housing(&"starter_coop")
	AnimalState.unregister_housing(&"starter_barn")
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	Wallet.load_save_data(_player_snapshot)
	Vitals.load_save_data(_vitals_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	WorldClock.set_time(_clock_day, _clock_minute)

func test_a_bought_chicken_moves_into_the_coop() -> void:
	assert_ne(AnimalState.purchase(&"chicken", &"starter_town"), &"")
	assert_eq(AnimalState.get_housing_occupancy(&"starter_coop"), 2)
	assert_eq(AnimalState.get_housing_occupancy(&"starter_barn"), 1)

func test_starter_animals_eat_one_hay_each() -> void:
	assert_eq(AnimalState.get_feed_item_ids(&"starter_town"), [&"hay"] as Array[StringName])
	WorldState.set_value(&"animal:starter_chicken_01", {"happiness": 50, "last_product_day": 1, "last_pet_day": 1, "last_fed_day": 1, "last_processed_day": 1})
	WorldClock.set_time(2, 8 * 60)
	assert_eq(AnimalState.get_feed_needs(&"starter_coop"), {&"hay": 1} as Dictionary[StringName, int])
	InventoryState.add_item_by_id(&"hay", 2)
	assert_eq(AnimalState.feed_housing(&"starter_coop"), 1)
	assert_eq(InventoryState.get_quantity(&"hay"), 1)

func test_general_store_sells_animals_as_shop_offers() -> void:
	var shop := ShopData.find(&"general_store")
	assert_not_null(shop)
	var offers: Dictionary = {}
	for offer: ShopOffer in shop.offers:
		offers[offer.get_key()] = offer
	assert_eq(offers.keys(), ["animal:chicken", "animal:cow", "animal:pig"])
	var context := {"location_id": &"starter_town"}
	var money_before := Wallet.money
	assert_true(ShopState.buy_offer(shop, offers["animal:cow"], context))
	assert_eq(Wallet.money, money_before - FarmAnimalData.find(&"cow").purchase_price)
	assert_eq(AnimalState.get_housing_occupancy(&"starter_barn"), 2)
	money_before = Wallet.money
	assert_true(ShopState.buy_offer(shop, offers["animal:pig"], context))
	assert_eq(Wallet.money, money_before - FarmAnimalData.find(&"pig").purchase_price)
	assert_eq(AnimalState.get_housing_occupancy(&"starter_barn"), 3)

func test_owned_animal_state_is_applied_to_scene_animals() -> void:
	WorldState.set_value(GameSession.NEW_GAME_FLAG, true)
	WorldState.set_value(&"animal:starter_chicken_01", {"happiness": 73, "last_product_day": 4, "last_pet_day": 3})
	var scene := load("res://game/world/dev_world.tscn") as PackedScene
	var world := scene.instantiate()
	add_child_autofree(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var chicken := world.get_node_or_null("Chicken") as FarmAnimal
	var cow := world.get_node_or_null("Cow") as FarmAnimal
	assert_not_null(chicken)
	assert_not_null(cow)
	if chicken != null:
		assert_eq(chicken.persistent_id, &"starter_chicken_01")
		assert_eq(chicken.happiness, 73)

func test_pig_uses_real_sheet_layout_and_truffle_interval() -> void:
	var pig_data := FarmAnimalData.find(&"pig")
	assert_not_null(pig_data)
	assert_eq(pig_data.frame_size, Vector2i(80, 48))
	assert_eq(pig_data.idle_from, 0)
	assert_eq(pig_data.idle_to, 7)
	assert_eq(pig_data.walk_from, 8)
	assert_eq(pig_data.walk_to, 14)
	assert_eq(pig_data.eat_from, 15)
	assert_eq(pig_data.eat_to, 22)
	assert_eq(pig_data.housing_type, &"barn")
	assert_eq(pig_data.product_item_id, &"truffle")
	assert_eq(pig_data.product_interval_days, 2)

func test_live_housing_updates_custom_name_and_removes_sold_animal() -> void:
	WorldState.set_value(GameSession.NEW_GAME_FLAG, true)
	var scene := load("res://game/world/dev_world.tscn") as PackedScene
	var world := scene.instantiate()
	add_child_autofree(world)
	await get_tree().process_frame
	await get_tree().process_frame
	var chicken := world.get_node_or_null("Chicken") as FarmAnimal
	assert_not_null(chicken)
	assert_not_null(world.get_node_or_null("WorldHud/AnimalManagementMenu"))
	assert_not_null(world.get_node_or_null("AnimalLedger"))
	assert_true(AnimalState.rename_animal(&"starter_chicken_01", "Clucky"))
	await get_tree().process_frame
	await get_tree().process_frame
	chicken = world.get_node_or_null("Chicken") as FarmAnimal
	assert_not_null(chicken)
	if chicken != null:
		assert_eq(chicken.get_display_name(), "Clucky")
	var refund := AnimalState.sell_animal(&"starter_chicken_01")
	assert_gt(refund, 0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(world.get_node_or_null("Chicken"))

func test_high_happiness_unlocks_premium_animal_products() -> void:
	var chicken_data := FarmAnimalData.find(&"chicken")
	var cow_data := FarmAnimalData.find(&"cow")
	var pig_data := FarmAnimalData.find(&"pig")
	assert_eq(chicken_data.get_product_item_id(79), &"egg")
	assert_eq(chicken_data.get_product_item_id(80), &"large_egg")
	assert_eq(cow_data.get_product_item_id(80), &"large_milk")
	assert_eq(pig_data.get_product_item_id(84), &"truffle")
	assert_eq(pig_data.get_product_item_id(85), &"prime_truffle")
	assert_gt(ItemData.find(&"large_egg").sell_price, ItemData.find(&"egg").sell_price)
	assert_gt(ItemData.find(&"large_milk").sell_price, ItemData.find(&"milk").sell_price)
	assert_gt(ItemData.find(&"prime_truffle").sell_price, ItemData.find(&"truffle").sell_price)
