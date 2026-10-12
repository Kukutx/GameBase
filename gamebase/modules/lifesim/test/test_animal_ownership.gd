extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const MenuFit := preload("res://gamebase/core/test/menu_fit.gd")
const ANIMAL_SCENE := preload("res://gamebase/modules/lifesim/animals/farm_animal.tscn")
const MENU_SCENE := preload("res://gamebase/modules/lifesim/animals/animal_management_menu.tscn")
const HEN_PRICE := 800

var _world_snapshot: Dictionary
var _player_snapshot: Dictionary
var _vitals_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _clock_day: int
var _clock_minute: int
var _inventory_slots: int

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_player_snapshot = Wallet.to_save_data()
	_vitals_snapshot = Vitals.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_clock_day = WorldClock.day
	_clock_minute = WorldClock.minute_of_day
	_inventory_slots = InventoryState.max_slots
	ContentFixture.use(self, _content())
	WorldState.clear()
	InventoryState.clear()
	Wallet.reset_new_game()
	Vitals.reset_new_game()
	Wallet.money = 10000
	WorldClock.set_time(1, 8 * 60)
	AnimalState.register_housing(&"fixture_coop", &"fixture_farm", &"coop", 4, "Coop")
	AnimalState.register_housing(&"fixture_barn", &"fixture_farm", &"barn", 4, "Barn")
	AnimalState.reset_new_game()
	AnimalState.grant_animal(&"fixture_hen_01", &"fixture_hen", &"fixture_farm", &"fixture_coop", 0)
	AnimalState.grant_animal(&"fixture_cow_01", &"fixture_cow", &"fixture_farm", &"fixture_barn", 0)

func after_each() -> void:
	# GUT frees the fixture content after after_each(): restore the saved state
	# against the game's own content.
	ContentRegistry.active = ContentDB
	AnimalState.unregister_housing(&"fixture_coop")
	AnimalState.unregister_housing(&"fixture_barn")
	# The clock first: animals still in the tree save their state when the day changes.
	WorldClock.set_time(_clock_day, _clock_minute)
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	Wallet.load_save_data(_player_snapshot)
	Vitals.load_save_data(_vitals_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	InventoryState.max_slots = _inventory_slots

func test_granted_animals_keep_stable_ids_and_housing_slots() -> void:
	var owned := AnimalState.get_owned(&"fixture_farm")
	assert_eq(owned.size(), 2)
	assert_eq(String(owned[0]["instance_id"]), "fixture_hen_01")
	assert_eq(String(owned[0]["node_name"]), "Hen")
	assert_eq(String(owned[0]["housing_id"]), "fixture_coop")
	assert_eq(String(owned[1]["instance_id"]), "fixture_cow_01")
	assert_eq(String(owned[1]["node_name"]), "Cow")
	assert_eq(String(owned[1]["housing_id"]), "fixture_barn")
	assert_eq(AnimalState.get_available_slots(&"fixture_farm", &"coop"), 3)
	assert_eq(AnimalState.get_available_slots(&"fixture_farm", &"barn"), 3)

func test_grant_rejects_unknown_animals_and_repeated_instances() -> void:
	assert_false(AnimalState.grant_animal(&"fixture_hen_01", &"fixture_hen", &"fixture_farm", &"fixture_coop", 1))
	assert_false(AnimalState.grant_animal(&"other", &"removed_animal_type", &"fixture_farm", &"fixture_coop", 1))
	assert_eq(AnimalState.get_housing_occupancy(&"fixture_coop"), 1)

func test_records_of_unknown_animals_are_dropped() -> void:
	var raw_records: Array = (WorldState.get_value(AnimalOwnershipService.OWNERSHIP_KEY, []) as Array).duplicate(true)
	raw_records.append({
		"instance_id": "removed_animal_01",
		"animal_id": "removed_animal_type",
		"location_id": "fixture_farm",
		"housing_id": "fixture_coop",
		"slot_index": 1,
		"node_name": "RemovedAnimal",
	})
	WorldState.set_value(AnimalOwnershipService.OWNERSHIP_KEY, raw_records)
	assert_eq(AnimalState.get_housing_occupancy(&"fixture_coop"), 1)
	assert_true(AnimalState.get_record(&"removed_animal_01").is_empty())

	var bought := AnimalState.purchase(&"fixture_hen", &"fixture_farm")
	assert_ne(bought, &"")
	assert_eq(int(AnimalState.get_record(bought).get("slot_index", -1)), 1)
	var stored: Array = WorldState.get_value(AnimalOwnershipService.OWNERSHIP_KEY, []) as Array
	assert_false(stored.any(func(record: Variant) -> bool:
		return String((record as Dictionary).get("instance_id", "")) == "removed_animal_01"
	))

func test_malformed_ownership_records_and_state_do_not_block_housing() -> void:
	var raw_records: Array = (WorldState.get_value(AnimalOwnershipService.OWNERSHIP_KEY, []) as Array).duplicate(true)
	raw_records.append({
		"instance_id": "",
		"animal_id": "fixture_hen",
		"location_id": "fixture_farm",
		"housing_id": "fixture_coop",
		"slot_index": {"bad": true},
	})
	raw_records.append({
		"instance_id": "fixture_hen_01",
		"animal_id": "fixture_hen",
		"location_id": "fixture_farm",
		"housing_id": "fixture_coop",
		"slot_index": [99],
	})
	raw_records.append("not a record")
	WorldState.set_value(AnimalOwnershipService.OWNERSHIP_KEY, raw_records)
	WorldState.set_value(AnimalOwnershipService.SEQUENCE_KEY, {"bad": true})
	WorldState.set_value(&"animal:fixture_hen_01", {"last_fed_day": {"bad": true}, "happiness": [1000]})

	assert_eq(AnimalState.get_housing_occupancy(&"fixture_coop"), 1)
	assert_eq(AnimalState.get_available_slots(&"fixture_farm", &"coop"), 3)
	assert_eq(AnimalState.get_unfed_count(&"fixture_coop"), 0)
	var bought := AnimalState.purchase(&"fixture_hen", &"fixture_farm")
	assert_eq(String(bought), "owned_fixture_hen_0001")
	assert_eq(WorldState.get_value(AnimalOwnershipService.SEQUENCE_KEY, 0), 1)
	assert_eq(AnimalState.get_housing_occupancy(&"fixture_coop"), 2)

func test_purchase_uses_correct_housing_and_money_and_respects_capacity() -> void:
	var money_before := Wallet.money
	var hen_id := AnimalState.purchase(&"fixture_hen", &"fixture_farm")
	assert_ne(hen_id, &"")
	assert_eq(Wallet.money, money_before - HEN_PRICE)
	assert_eq(AnimalState.get_housing_occupancy(&"fixture_coop"), 2)
	assert_eq(AnimalState.get_housing_occupancy(&"fixture_barn"), 1)

	assert_ne(AnimalState.purchase(&"fixture_hen", &"fixture_farm"), &"")
	assert_ne(AnimalState.purchase(&"fixture_hen", &"fixture_farm"), &"")
	assert_eq(AnimalState.get_housing_occupancy(&"fixture_coop"), 4)
	assert_eq(AnimalState.purchase(&"fixture_hen", &"fixture_farm"), &"")

func test_animal_purchase_blocks_money_callback_reentrancy() -> void:
	AnimalState.register_housing(&"race_coop", &"race_town", &"coop", 1, "Coop")
	Wallet.money = 5000
	var observed := {"entered": false, "inner_id": StringName()}
	var race_purchase := func(_money: int) -> void:
		if bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_id"] = AnimalState.purchase(&"fixture_hen", &"race_town")
	Wallet.money_changed.connect(race_purchase)

	var outer_id := AnimalState.purchase(&"fixture_hen", &"race_town")
	if Wallet.money_changed.is_connected(race_purchase):
		Wallet.money_changed.disconnect(race_purchase)
	assert_ne(outer_id, &"")
	assert_eq(observed["inner_id"] as StringName, &"")
	assert_eq(AnimalState.get_housing_occupancy(&"race_coop"), 1)
	assert_eq(AnimalState.get_housing_capacity(&"race_coop"), 1)
	assert_eq(Wallet.money, 5000 - HEN_PRICE)
	AnimalState.unregister_housing(&"race_coop")

func test_shop_sells_animals_as_offers_that_move_into_free_housing() -> void:
	var cow_offer := _offer(&"fixture_cow")
	var pig_offer := _offer(&"fixture_pig")
	var shop := ShopData.new()
	shop.id = &"fixture_shop"
	shop.offers.assign([cow_offer, pig_offer])
	assert_eq(cow_offer.get_key(), "animal:fixture_cow")
	var context := {"location_id": &"fixture_farm"}
	assert_true(cow_offer.can_buy(context))
	assert_false(cow_offer.can_buy({}), "an animal is bought for a location")

	var money_before := Wallet.money
	assert_true(ShopState.buy_offer(shop, cow_offer, context))
	assert_eq(Wallet.money, money_before - FarmAnimalData.find(&"fixture_cow").purchase_price)
	assert_eq(AnimalState.get_housing_occupancy(&"fixture_barn"), 2)
	money_before = Wallet.money
	assert_true(ShopState.buy_offer(shop, pig_offer, context))
	assert_eq(Wallet.money, money_before - FarmAnimalData.find(&"fixture_pig").purchase_price)
	assert_eq(AnimalState.get_housing_occupancy(&"fixture_barn"), 3)
	assert_false(ShopState.buy_offer(shop, _offer(&"fixture_cow"), context), "an offer the shop does not list is not sold")
	assert_eq(AnimalState.get_housing_occupancy(&"fixture_barn"), 3)

func test_housing_spawns_owned_animals_with_their_state_and_follows_renames_and_sales() -> void:
	WorldState.set_value(&"animal:fixture_hen_01", {"happiness": 73, "last_product_day": 1, "last_pet_day": 1, "last_fed_day": 1, "last_processed_day": 1})
	var yard := Node2D.new()
	add_child_autofree(yard)
	var housing := AnimalHousing.new()
	housing.housing_id = &"fixture_coop"
	housing.location_id = &"fixture_farm"
	housing.housing_type = &"coop"
	housing.display_name = "Coop"
	yard.add_child(housing)
	await get_tree().process_frame
	await get_tree().process_frame
	var hen := yard.get_node_or_null("Hen") as FarmAnimal
	assert_not_null(hen)
	assert_null(yard.get_node_or_null("Cow"), "a housing spawns only its own animals")
	if hen == null:
		return
	assert_eq(hen.persistent_id, &"fixture_hen_01")
	assert_eq(hen.happiness, 73)
	assert_eq(housing.get_spawned_animals(), [hen] as Array[FarmAnimal])

	assert_true(AnimalState.rename_animal(&"fixture_hen_01", "Clucky"))
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(hen.get_display_name(), "Clucky")
	assert_gt(AnimalState.sell_animal(&"fixture_hen_01"), 0)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_null(yard.get_node_or_null("Hen"))

func test_loaded_animal_state_clamps_future_daily_markers() -> void:
	WorldClock.set_time(10, 8 * 60)
	var hen := ANIMAL_SCENE.instantiate() as FarmAnimal
	hen.data = FarmAnimalData.find(&"fixture_hen")
	hen.persistent_id = &""
	add_child_autofree(hen)
	hen.load_state_data({
		"happiness": 999,
		"last_product_day": 999999,
		"last_pet_day": 999999,
		"last_fed_day": 999999,
		"last_processed_day": 999999,
	}, false)
	assert_eq(hen.happiness, 100)
	assert_eq(hen.last_product_day, 10)
	assert_eq(hen.last_pet_day, 10)
	assert_eq(hen.last_fed_day, 10)
	assert_eq(hen.last_processed_day, 10)
	assert_true(hen.is_fed_today())

func test_product_interval_counts_days_and_needs_the_animal_fed() -> void:
	var pig_data := FarmAnimalData.find(&"fixture_pig")
	assert_eq(pig_data.product_interval_days, 2)
	var pig := ANIMAL_SCENE.instantiate() as FarmAnimal
	pig.data = pig_data
	pig.persistent_id = &"test_pig_production"
	add_child_autofree(pig)
	await get_tree().process_frame
	assert_true(pig.is_product_ready(), "an animal with no history has its product ready")
	pig.get_node("Interactable").interact(null)
	assert_eq(InventoryState.get_quantity(&"fixture_truffle"), 1)
	assert_false(pig.is_product_ready())
	WorldClock.set_time(2, 8 * 60)
	await get_tree().process_frame
	assert_false(pig.is_product_ready())
	WorldClock.set_time(3, 8 * 60)
	await get_tree().process_frame
	assert_false(pig.is_product_ready(), "two days have passed, but the pig is not fed today")
	pig.last_fed_day = WorldClock.day
	assert_true(pig.is_product_ready())

func test_multi_product_collection_waits_until_the_full_output_fits() -> void:
	var hen_data := FarmAnimalData.find(&"fixture_hen")
	hen_data.product_quantity = 2
	WorldState.set_value(&"animal:test_multi_product", {
		"happiness": 50,
		"last_product_day": 0,
		"last_pet_day": 0,
		"last_fed_day": 1,
		"last_processed_day": 1,
	})
	var hen := ANIMAL_SCENE.instantiate() as FarmAnimal
	hen.data = hen_data
	hen.persistent_id = &"test_multi_product"
	add_child_autofree(hen)
	await get_tree().process_frame
	assert_true(hen.is_product_ready())

	InventoryState.clear()
	InventoryState.max_slots = 1
	InventoryState.add_item_by_id(&"fixture_egg", 23)
	hen.get_node("Interactable").interact(null)
	assert_eq(InventoryState.get_quantity(&"fixture_egg"), 23)
	assert_true(hen.is_product_ready())
	assert_eq(hen.last_product_day, 0)

	assert_true(InventoryState.remove_item(&"fixture_egg", 1))
	hen.get_node("Interactable").interact(null)
	assert_eq(InventoryState.get_quantity(&"fixture_egg"), 24)
	assert_false(hen.is_product_ready())
	assert_eq(hen.last_product_day, WorldClock.day)

func test_product_collection_blocks_item_added_reentrancy() -> void:
	WorldState.set_value(&"animal:test_product_reentrancy", {
		"happiness": 50,
		"last_product_day": 0,
		"last_pet_day": 0,
		"last_fed_day": WorldClock.day,
		"last_processed_day": WorldClock.day,
	})
	var hen := ANIMAL_SCENE.instantiate() as FarmAnimal
	hen.data = FarmAnimalData.find(&"fixture_hen")
	hen.persistent_id = &"test_product_reentrancy"
	add_child_autofree(hen)
	await get_tree().process_frame
	assert_true(hen.is_product_ready())
	var observed := {"entered": false}
	var listener := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"fixture_egg" or bool(observed["entered"]):
			return
		observed["entered"] = true
		hen.get_node("Interactable").interact(null)
	InventoryState.item_added.connect(listener)
	hen.get_node("Interactable").interact(null)
	if InventoryState.item_added.is_connected(listener):
		InventoryState.item_added.disconnect(listener)
	assert_true(bool(observed["entered"]))
	assert_eq(InventoryState.get_quantity(&"fixture_egg"), 1)
	assert_eq(hen.last_product_day, WorldClock.day)
	assert_false(hen.is_product_ready())

func test_feed_housing_consumes_one_feed_per_unfed_animal_and_is_idempotent() -> void:
	WorldState.set_value(&"animal:fixture_hen_01", {
		"happiness": 50,
		"last_product_day": 1,
		"last_pet_day": 1,
		"last_fed_day": 1,
		"last_processed_day": 1,
	})
	InventoryState.add_item_by_id(&"fixture_hay", 2)
	WorldClock.set_time(2, 8 * 60)
	assert_eq(AnimalState.get_unfed_count(&"fixture_coop"), 1)
	assert_eq(AnimalState.feed_housing(&"fixture_coop"), 1)
	assert_eq(InventoryState.get_quantity(&"fixture_hay"), 1)
	assert_eq(AnimalState.get_unfed_count(&"fixture_coop"), 0)
	assert_eq(AnimalState.feed_housing(&"fixture_coop"), 0)
	assert_eq(InventoryState.get_quantity(&"fixture_hay"), 1)

func test_housings_name_themselves_and_report_what_their_animals_eat() -> void:
	assert_eq(AnimalState.get_housing_ids(&"fixture_farm"), [&"fixture_coop", &"fixture_barn"] as Array[StringName])
	assert_eq(AnimalState.get_housing_name(&"fixture_barn"), "Barn")
	assert_eq(AnimalState.get_feed_item_ids(&"fixture_farm"), [&"fixture_hay"] as Array[StringName])
	assert_true(AnimalState.get_feed_needs(&"fixture_coop").is_empty())
	WorldState.set_value(&"animal:fixture_hen_01", {"happiness": 50, "last_product_day": 1, "last_pet_day": 1, "last_fed_day": 1, "last_processed_day": 1})
	WorldClock.set_time(2, 8 * 60)
	assert_eq(AnimalState.get_feed_needs(&"fixture_coop"), {&"fixture_hay": 1} as Dictionary[StringName, int])
	assert_eq(AnimalState.feed_housing(&"fixture_coop"), 0, "No feed in the inventory")

func test_feed_housing_blocks_item_removed_reentrancy() -> void:
	WorldState.set_value(&"animal:fixture_hen_01", {
		"happiness": 50,
		"last_product_day": 1,
		"last_pet_day": 1,
		"last_fed_day": 1,
		"last_processed_day": 1,
	})
	WorldClock.set_time(2, 8 * 60)
	InventoryState.add_item_by_id(&"fixture_hay", 2)
	var observed := {"entered": false, "inner_fed": -1}
	var listener := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"fixture_hay" or bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_fed"] = AnimalState.feed_housing(&"fixture_coop")
	InventoryState.item_removed.connect(listener)
	assert_eq(AnimalState.feed_housing(&"fixture_coop"), 1)
	if InventoryState.item_removed.is_connected(listener):
		InventoryState.item_removed.disconnect(listener)
	assert_true(bool(observed["entered"]))
	assert_eq(int(observed["inner_fed"]), 0)
	assert_eq(InventoryState.get_quantity(&"fixture_hay"), 1)
	assert_eq(AnimalState.get_unfed_count(&"fixture_coop"), 0)

func test_animal_offline_catchup_penalizes_missed_feed_and_feeding_restores_production() -> void:
	WorldState.set_value(&"animal:fixture_hen_01", {
		"happiness": 60,
		"last_product_day": 1,
		"last_pet_day": 1,
		"last_fed_day": 1,
		"last_processed_day": 1,
	})
	WorldClock.set_time(4, 8 * 60)
	var hen := ANIMAL_SCENE.instantiate() as FarmAnimal
	hen.data = FarmAnimalData.find(&"fixture_hen")
	hen.persistent_id = &"fixture_hen_01"
	add_child_autofree(hen)
	await get_tree().process_frame
	# Two days without petting (1 each) and two without feed (3 each).
	assert_eq(hen.happiness, 52)
	assert_false(hen.is_fed_today())
	assert_false(hen.is_product_ready())
	InventoryState.add_item_by_id(&"fixture_hay", 1)
	assert_eq(AnimalState.feed_housing(&"fixture_coop"), 1)
	await get_tree().process_frame
	assert_true(hen.is_fed_today())
	assert_true(hen.is_product_ready())
	assert_eq(InventoryState.get_quantity(&"fixture_hay"), 0)

func test_animal_catchup_handles_extreme_day_jump_without_per_day_iteration() -> void:
	var hen := ANIMAL_SCENE.instantiate() as FarmAnimal
	hen.data = FarmAnimalData.find(&"fixture_hen")
	hen.persistent_id = &""
	add_child_autofree(hen)
	await get_tree().process_frame
	hen.happiness = 60
	hen.last_pet_day = 1
	hen.last_fed_day = 1
	hen.last_processed_day = 1
	hen.call("_advance_to_day", 1_000_000)
	assert_eq(hen.last_processed_day, 1_000_000)
	assert_eq(hen.happiness, 0)

func test_animal_catchup_commits_processed_day_before_happiness_signal_reentrancy() -> void:
	WorldState.set_value(&"animal:test_catchup_reentrancy", {
		"happiness": 60,
		"last_product_day": 1,
		"last_pet_day": 1,
		"last_fed_day": 1,
		"last_processed_day": 1,
	})
	var hen := ANIMAL_SCENE.instantiate() as FarmAnimal
	hen.data = FarmAnimalData.find(&"fixture_hen")
	hen.persistent_id = &"test_catchup_reentrancy"
	add_child_autofree(hen)
	await get_tree().process_frame
	var entered := {"value": false}
	var advance_again := func(_happiness: int) -> void:
		if bool(entered["value"]):
			return
		entered["value"] = true
		WorldClock.set_time(4, 8 * 60)
	hen.happiness_changed.connect(advance_again)
	WorldClock.set_time(3, 8 * 60)
	if hen.happiness_changed.is_connected(advance_again):
		hen.happiness_changed.disconnect(advance_again)
	assert_true(bool(entered["value"]))
	assert_eq(WorldClock.day, 4)
	assert_eq(hen.last_processed_day, 4)
	assert_eq(hen.happiness, 52)

func test_animals_can_be_renamed_and_sold_with_half_price_refund() -> void:
	var instance_id := AnimalState.purchase(&"fixture_hen", &"fixture_farm")
	assert_ne(instance_id, &"")
	assert_true(AnimalState.rename_animal(instance_id, "Pip"))
	assert_false(AnimalState.rename_animal(instance_id, ""))
	var record := AnimalState.get_record(instance_id)
	assert_eq(String(record.get("custom_name", "")), "Pip")
	var money_before_sale := Wallet.money
	var expected_refund := int(round(float(HEN_PRICE) * 0.5))
	var refund := AnimalState.sell_animal(instance_id)
	assert_eq(refund, expected_refund)
	assert_eq(Wallet.money, money_before_sale + expected_refund)
	assert_true(AnimalState.get_record(instance_id).is_empty())
	assert_eq(AnimalState.get_housing_occupancy(&"fixture_coop"), 1)
	assert_eq(WorldState.get_value(StringName("animal:%s" % String(instance_id)), null), null)

func test_high_happiness_unlocks_premium_animal_products() -> void:
	var hen_data := FarmAnimalData.find(&"fixture_hen")
	assert_eq(hen_data.get_product_item_id(79), &"fixture_egg")
	assert_eq(hen_data.get_product_item_id(80), &"fixture_large_egg")
	assert_eq(FarmAnimalData.find(&"fixture_cow").get_product_item_id(100), &"fixture_milk", "an animal without a premium product")

	WorldState.set_value(&"animal:test_happy_hen", {
		"happiness": 85,
		"last_product_day": 0,
		"last_pet_day": 0,
		"last_fed_day": 1,
		"last_processed_day": 1,
	})
	var hen := ANIMAL_SCENE.instantiate() as FarmAnimal
	hen.data = hen_data
	hen.persistent_id = &"test_happy_hen"
	add_child_autofree(hen)
	await get_tree().process_frame
	assert_true(hen.is_product_ready())
	hen.get_node("Interactable").interact(null)
	assert_eq(InventoryState.get_quantity(&"fixture_large_egg"), 1)
	assert_eq(InventoryState.get_quantity(&"fixture_egg"), 0)

func test_animal_name_typed_by_the_player_is_shown_as_plain_text() -> void:
	assert_true(AnimalState.rename_animal(&"fixture_hen_01", "[i]Bessie[/i]"))
	var menu := MENU_SCENE.instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame
	menu.open(&"fixture_farm")
	InputLock.clear()
	var details := menu.get_node("Panel/VBox/Details") as RichTextLabel
	assert_true(details.text.contains("[lb]i]Bessie[lb]/i]"), details.text)
	assert_true(details.get_parsed_text().contains("[i]Bessie[/i]"), details.get_parsed_text())

func test_the_animal_ledger_holds_the_focus_and_fits_the_view() -> void:
	var menu := MENU_SCENE.instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame
	menu.open(&"fixture_farm")
	await get_tree().process_frame
	assert_eq(MenuFit.find_focus_problem(menu), "", "with animals")
	await get_tree().process_frame
	assert_eq(MenuFit.find_overflow(menu, get_viewport().get_visible_rect()), PackedStringArray())
	menu.close()
	menu.open(&"fixture_empty_field")
	await get_tree().process_frame
	assert_eq(MenuFit.find_focus_problem(menu), "", "with no animal and no housing")
	await get_tree().process_frame
	assert_eq(MenuFit.find_overflow(menu, get_viewport().get_visible_rect()), PackedStringArray())
	menu.close()

func _content() -> Array:
	var hen := _animal(&"fixture_hen", "Hen", &"coop", HEN_PRICE, &"fixture_egg")
	hen.premium_product_item_id = &"fixture_large_egg"
	hen.premium_happiness_threshold = 80
	var cow := _animal(&"fixture_cow", "Cow", &"barn", 1500, &"fixture_milk")
	var pig := _animal(&"fixture_pig", "Pig", &"barn", 2400, &"fixture_truffle")
	pig.product_interval_days = 2
	var egg := _item(&"fixture_egg", "animal_product")
	egg.max_stack = 24
	return [hen, cow, pig, egg, _item(&"fixture_large_egg", "animal_product"), _item(&"fixture_milk", "animal_product"),
		_item(&"fixture_truffle", "animal_product"), _item(&"fixture_hay", "animal_feed")]

func _animal(id: StringName, display_name: String, housing_type: StringName, price: int, product_id: StringName) -> FarmAnimalData:
	var animal := FarmAnimalData.new()
	animal.id = id
	animal.display_name = display_name
	animal.housing_type = housing_type
	animal.purchase_price = price
	animal.feed_item_id = &"fixture_hay"
	animal.product_item_id = product_id
	animal.missed_feed_happiness_loss = 3
	return animal

func _item(id: StringName, tag: String) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	item.tags = PackedStringArray([tag])
	return item

func _offer(animal_id: StringName) -> AnimalOffer:
	var offer := AnimalOffer.new()
	offer.animal_id = animal_id
	return offer
