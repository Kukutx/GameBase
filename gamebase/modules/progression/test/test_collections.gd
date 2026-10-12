extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

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
	var crop := CropData.new()
	crop.id = &"fixture_radish_crop"
	crop.harvest_item_id = &"fixture_radish"
	var fish := FishData.new()
	fish.id = &"fixture_trout_fish"
	fish.item_id = &"fixture_trout"
	var rock := MiningNodeData.new()
	rock.id = &"fixture_pebble_rock"
	rock.drop_item_id = &"fixture_pebble"
	var hen := FarmAnimalData.new()
	hen.id = &"fixture_hen"
	hen.product_item_id = &"fixture_egg"
	hen.premium_product_item_id = &"fixture_big_egg"
	var press := ProcessingRecipeData.new()
	press.id = &"fixture_press"
	press.output_item_id = &"fixture_oil"
	var patch := ForageEntryData.new()
	patch.id = &"fixture_berry_patch"
	patch.item_id = &"fixture_berry"
	ContentFixture.use(self, [
		crop, fish, rock, hen, press, patch,
		_item(&"fixture_radish", ItemData.Kind.CROP, 30),
		_item(&"fixture_berry", ItemData.Kind.FOOD, 10),
		_item(&"fixture_rod", ItemData.Kind.TOOL, 50),
		_item(&"fixture_letter", ItemData.Kind.QUEST, 5),
		_item(&"fixture_pebble", ItemData.Kind.MATERIAL, 0),
	])

func after_each() -> void:
	# The game's content is active again before the stores load their items.
	ContentRegistry.active = ContentDB
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	ShippingState.load_save_data(_shipping_snapshot)

func test_an_item_is_discovered_once() -> void:
	var discovered: Array[StringName] = []
	var on_discovered := func(_category: StringName, item_id: StringName) -> void: discovered.append(item_id)
	CollectionState.item_discovered.connect(on_discovered)
	CollectionState.record(CollectionService.CROPS, &"fixture_radish", 2)
	CollectionState.record(CollectionService.CROPS, &"fixture_radish", 1)
	CollectionState.record(CollectionService.FISH, &"fixture_trout", 1)
	CollectionState.item_discovered.disconnect(on_discovered)
	assert_eq(discovered, [&"fixture_radish", &"fixture_trout"] as Array[StringName])
	assert_eq(CollectionState.get_discovered_count(CollectionService.CROPS), 1)
	assert_eq(CollectionState.get_total_count(CollectionService.CROPS), 1)

func test_collection_records_gameplay_categories_and_accumulates_counts() -> void:
	LifesimEvents.crop_harvested.emit(&"fixture_radish_crop", &"fixture_radish", 2)
	LifesimEvents.crop_harvested.emit(&"fixture_radish_crop", &"fixture_radish", 1)
	LifesimEvents.fish_caught.emit(&"fixture_trout_fish", &"fixture_trout")
	LifesimEvents.resource_mined.emit(&"fixture_pebble_rock", &"fixture_pebble", 3)
	LifesimEvents.animal_product_collected.emit(&"fixture_hen", &"fixture_egg", 2)
	LifesimEvents.item_processed.emit(&"fixture_press", &"fixture_oil", 1)
	ItemsEvents.item_foraged.emit(&"fixture_berry", 4)

	assert_eq(CollectionState.get_count(CollectionService.CROPS, &"fixture_radish"), 3)
	assert_eq(CollectionState.get_count(CollectionService.FISH, &"fixture_trout"), 1)
	assert_eq(CollectionState.get_count(CollectionService.MINERALS, &"fixture_pebble"), 3)
	assert_eq(CollectionState.get_count(CollectionService.ANIMAL_PRODUCTS, &"fixture_egg"), 2)
	assert_eq(CollectionState.get_count(CollectionService.PROCESSED, &"fixture_oil"), 1)
	assert_eq(CollectionState.get_count(CollectionService.FORAGE, &"fixture_berry"), 4)

func test_shipping_automatically_records_collection_progress() -> void:
	InventoryState.add_item_by_id(&"fixture_radish", 2)
	assert_true(ShippingState.ship_item(&"fixture_radish", 2))
	assert_eq(CollectionState.get_count(CollectionService.SHIPPED, &"fixture_radish"), 2)

func test_collection_catalog_lists_what_each_kind_of_content_yields() -> void:
	assert_eq(CollectionState.get_total_ids(CollectionService.CROPS), [&"fixture_radish"])
	assert_eq(CollectionState.get_total_ids(CollectionService.FISH), [&"fixture_trout"])
	assert_eq(CollectionState.get_total_ids(CollectionService.MINERALS), [&"fixture_pebble"])
	assert_eq(CollectionState.get_total_ids(CollectionService.ANIMAL_PRODUCTS), [&"fixture_big_egg", &"fixture_egg"], "an animal's premium product counts too")
	assert_eq(CollectionState.get_total_ids(CollectionService.PROCESSED), [&"fixture_oil"])
	assert_eq(CollectionState.get_total_ids(CollectionService.FORAGE), [&"fixture_berry"])
	assert_eq(CollectionState.get_total_ids(CollectionService.SHIPPED), [&"fixture_berry", &"fixture_radish"], "tools, quest items and items without a price are not shipped")

func test_collection_sanitizes_malformed_nested_counts_and_repairs_on_record() -> void:
	WorldState.set_value(CollectionService.STATE_KEY, {
		"crops": {"fixture_radish": {"bad": true}, "fixture_gourd": -5},
		"fish": "malformed",
	})
	assert_eq(CollectionState.get_count(CollectionService.CROPS, &"fixture_radish"), 0)
	assert_eq(CollectionState.get_count(CollectionService.CROPS, &"fixture_gourd"), 0)
	assert_eq(CollectionState.get_count(CollectionService.FISH, &"fixture_trout"), 0)
	assert_eq(CollectionState.record(CollectionService.CROPS, &"fixture_radish", 2), 2)
	assert_eq(CollectionState.record(CollectionService.FISH, &"fixture_trout", 1), 1)
	assert_eq(CollectionState.get_count(CollectionService.CROPS, &"fixture_radish"), 2)
	assert_eq(CollectionState.get_count(CollectionService.FISH, &"fixture_trout"), 1)

func test_collection_state_round_trips_through_world_state() -> void:
	CollectionState.record(CollectionService.CROPS, &"fixture_gourd", 4)
	CollectionState.record(CollectionService.FISH, &"fixture_trout", 2)
	var snapshot := WorldState.to_save_data()
	WorldState.clear()
	assert_eq(CollectionState.get_count(CollectionService.CROPS, &"fixture_gourd"), 0)
	WorldState.load_save_data(snapshot)
	assert_eq(CollectionState.get_count(CollectionService.CROPS, &"fixture_gourd"), 4)
	assert_eq(CollectionState.get_count(CollectionService.FISH, &"fixture_trout"), 2)

func _item(id: StringName, kind: ItemData.Kind, sell_price: int) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	item.kind = kind
	item.sell_price = sell_price
	if kind == ItemData.Kind.TOOL:
		item.max_stack = 1
		item.tool_action = FishingSpot.TOOL_ACTION
	return item
