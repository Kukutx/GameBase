extends GutTest

var _world_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _shipping_snapshot: Dictionary

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_shipping_snapshot = ShippingState.to_save_data()
	WorldState.clear()
	InventoryState.clear()
	ShippingState.load_save_data({"pending": {}, "last_day_seen": WorldClock.day})

func after_each() -> void:
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	ShippingState.load_save_data(_shipping_snapshot)

func test_collection_records_gameplay_categories_and_accumulates_counts() -> void:
	LifesimEvents.crop_harvested.emit(&"turnip", &"turnip", 2)
	LifesimEvents.crop_harvested.emit(&"turnip", &"turnip", 1)
	LifesimEvents.fish_caught.emit(&"river_trout", &"river_trout")
	LifesimEvents.resource_mined.emit(&"stone_rock", &"stone", 3)
	LifesimEvents.animal_product_collected.emit(&"chicken", &"egg", 2)
	LifesimEvents.item_processed.emit(&"press_truffle_oil", &"truffle_oil", 1)
	ItemsEvents.item_foraged.emit(&"berry", 4)

	assert_eq(CollectionState.get_count(CollectionService.CROPS, &"turnip"), 3)
	assert_eq(CollectionState.get_count(CollectionService.FISH, &"river_trout"), 1)
	assert_eq(CollectionState.get_count(CollectionService.MINERALS, &"stone"), 3)
	assert_eq(CollectionState.get_count(CollectionService.ANIMAL_PRODUCTS, &"egg"), 2)
	assert_eq(CollectionState.get_count(CollectionService.PROCESSED, &"truffle_oil"), 1)
	assert_eq(CollectionState.get_count(CollectionService.FORAGE, &"berry"), 4)

func test_shipping_automatically_records_collection_progress() -> void:
	InventoryState.add_item_by_id(&"turnip", 2)
	assert_true(ShippingState.ship_item(&"turnip", 2))
	assert_eq(CollectionState.get_count(CollectionService.SHIPPED, &"turnip"), 2)

func test_collection_catalog_includes_new_seasons_animals_and_processing_content() -> void:
	assert_true(CollectionState.get_total_ids(CollectionService.CROPS).has(&"tomato"))
	assert_true(CollectionState.get_total_ids(CollectionService.CROPS).has(&"pumpkin"))
	assert_true(CollectionState.get_total_ids(CollectionService.CROPS).has(&"frostroot"))
	var animal_products := CollectionState.get_total_ids(CollectionService.ANIMAL_PRODUCTS)
	for item_id: StringName in [&"egg", &"large_egg", &"milk", &"large_milk", &"truffle", &"prime_truffle"]:
		assert_true(animal_products.has(item_id), "Animal collection is missing %s" % item_id)
	assert_eq(animal_products.size(), 6)
	assert_true(CollectionState.get_total_ids(CollectionService.PROCESSED).has(&"truffle_oil"))
	assert_true(CollectionState.get_total_ids(CollectionService.PROCESSED).has(&"iridium_bar"))
	assert_gt(CollectionState.get_total_ids(CollectionService.SHIPPED).size(), 10)

func test_collection_sanitizes_malformed_nested_counts_and_repairs_on_record() -> void:
	WorldState.set_value(CollectionService.STATE_KEY, {
		"crops": {"turnip": {"bad": true}, "tomato": -5},
		"fish": "malformed",
	})
	assert_eq(CollectionState.get_count(CollectionService.CROPS, &"turnip"), 0)
	assert_eq(CollectionState.get_count(CollectionService.CROPS, &"tomato"), 0)
	assert_eq(CollectionState.get_count(CollectionService.FISH, &"river_trout"), 0)
	assert_eq(CollectionState.record(CollectionService.CROPS, &"turnip", 2), 2)
	assert_eq(CollectionState.record(CollectionService.FISH, &"river_trout", 1), 1)
	assert_eq(CollectionState.get_count(CollectionService.CROPS, &"turnip"), 2)
	assert_eq(CollectionState.get_count(CollectionService.FISH, &"river_trout"), 1)

func test_collection_state_round_trips_through_world_state() -> void:
	CollectionState.record(CollectionService.CROPS, &"tomato", 4)
	CollectionState.record(CollectionService.FISH, &"mackerel", 2)
	var snapshot := WorldState.to_save_data()
	WorldState.clear()
	assert_eq(CollectionState.get_count(CollectionService.CROPS, &"tomato"), 0)
	WorldState.load_save_data(snapshot)
	assert_eq(CollectionState.get_count(CollectionService.CROPS, &"tomato"), 4)
	assert_eq(CollectionState.get_count(CollectionService.FISH, &"mackerel"), 2)
