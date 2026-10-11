extends GutTest

## The collection catalog Farm1's content yields. How collections record and
## save is tested with the progression module.

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
