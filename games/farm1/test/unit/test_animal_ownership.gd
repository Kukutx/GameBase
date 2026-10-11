extends GutTest

var _world_snapshot: Dictionary
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _clock_day: int
var _clock_minute: int
var _inventory_slots: int

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_clock_day = WorldClock.day
	_clock_minute = WorldClock.minute_of_day
	_inventory_slots = InventoryState.max_slots
	WorldState.clear()
	InventoryState.clear()
	PlayerState.reset_new_game()
	PlayerState.money = 10000
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
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	InventoryState.max_slots = _inventory_slots
	WorldClock.set_time(_clock_day, _clock_minute)

func test_granted_animals_keep_stable_ids_and_housing_slots() -> void:
	var owned := AnimalState.get_owned(&"starter_town")
	assert_eq(owned.size(), 2)
	assert_eq(String(owned[0]["instance_id"]), "starter_chicken_01")
	assert_eq(String(owned[0]["node_name"]), "Chicken")
	assert_eq(String(owned[0]["housing_id"]), "starter_coop")
	assert_eq(String(owned[1]["instance_id"]), "starter_cow_01")
	assert_eq(String(owned[1]["node_name"]), "Cow")
	assert_eq(String(owned[1]["housing_id"]), "starter_barn")
	assert_eq(AnimalState.get_available_slots(&"starter_town", &"coop"), 3)
	assert_eq(AnimalState.get_available_slots(&"starter_town", &"barn"), 3)

func test_grant_rejects_unknown_animals_and_repeated_instances() -> void:
	assert_false(AnimalState.grant_animal(&"starter_chicken_01", &"chicken", &"starter_town", &"starter_coop", 1))
	assert_false(AnimalState.grant_animal(&"other", &"removed_animal_type", &"starter_town", &"starter_coop", 1))
	assert_eq(AnimalState.get_housing_occupancy(&"starter_coop"), 1)

func test_records_of_unknown_animals_are_dropped() -> void:
	var raw_records: Array = (WorldState.get_value(AnimalOwnershipService.OWNERSHIP_KEY, []) as Array).duplicate(true)
	raw_records.append({
		"instance_id": "removed_animal_01",
		"animal_id": "removed_animal_type",
		"location_id": "starter_town",
		"housing_id": "starter_coop",
		"slot_index": 1,
		"node_name": "RemovedAnimal",
	})
	WorldState.set_value(AnimalOwnershipService.OWNERSHIP_KEY, raw_records)
	assert_eq(AnimalState.get_housing_occupancy(&"starter_coop"), 1)
	assert_true(AnimalState.get_record(&"removed_animal_01").is_empty())

	var bought := AnimalState.purchase(&"chicken", &"starter_town")
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
		"animal_id": "chicken",
		"location_id": "starter_town",
		"housing_id": "starter_coop",
		"slot_index": {"bad": true},
	})
	raw_records.append({
		"instance_id": "starter_chicken_01",
		"animal_id": "chicken",
		"location_id": "starter_town",
		"housing_id": "starter_coop",
		"slot_index": [99],
	})
	raw_records.append("not a record")
	WorldState.set_value(AnimalOwnershipService.OWNERSHIP_KEY, raw_records)
	WorldState.set_value(AnimalOwnershipService.SEQUENCE_KEY, {"bad": true})
	WorldState.set_value(&"animal:starter_chicken_01", {"last_fed_day": {"bad": true}, "happiness": [1000]})

	assert_eq(AnimalState.get_housing_occupancy(&"starter_coop"), 1)
	assert_eq(AnimalState.get_available_slots(&"starter_town", &"coop"), 3)
	assert_eq(AnimalState.get_unfed_count(&"starter_coop"), 0)
	var bought := AnimalState.purchase(&"chicken", &"starter_town")
	assert_eq(String(bought), "owned_chicken_0001")
	assert_eq(WorldState.get_value(AnimalOwnershipService.SEQUENCE_KEY, 0), 1)
	assert_eq(AnimalState.get_housing_occupancy(&"starter_coop"), 2)

func test_purchase_uses_correct_housing_and_money_and_respects_capacity() -> void:
	var money_before := PlayerState.money
	var chicken_id := AnimalState.purchase(&"chicken", &"starter_town")
	assert_ne(chicken_id, &"")
	assert_eq(PlayerState.money, money_before - ContentDB.get_farm_animal(&"chicken").purchase_price)
	assert_eq(AnimalState.get_housing_occupancy(&"starter_coop"), 2)
	assert_eq(AnimalState.get_housing_occupancy(&"starter_barn"), 1)

	assert_ne(AnimalState.purchase(&"chicken", &"starter_town"), &"")
	assert_ne(AnimalState.purchase(&"chicken", &"starter_town"), &"")
	assert_eq(AnimalState.get_housing_occupancy(&"starter_coop"), 4)
	assert_eq(AnimalState.purchase(&"chicken", &"starter_town"), &"")

func test_animal_purchase_blocks_money_callback_reentrancy() -> void:
	AnimalState.register_housing(&"race_coop", &"race_town", &"coop", 1, "Coop")
	PlayerState.money = 5000
	var observed := {"entered": false, "inner_id": StringName()}
	var race_purchase := func(_money: int) -> void:
		if bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_id"] = AnimalState.purchase(&"chicken", &"race_town")
	PlayerState.money_changed.connect(race_purchase)

	var outer_id := AnimalState.purchase(&"chicken", &"race_town")
	if PlayerState.money_changed.is_connected(race_purchase):
		PlayerState.money_changed.disconnect(race_purchase)
	assert_ne(outer_id, &"")
	assert_eq(observed["inner_id"] as StringName, &"")
	assert_eq(AnimalState.get_housing_occupancy(&"race_coop"), 1)
	assert_eq(AnimalState.get_housing_capacity(&"race_coop"), 1)
	assert_eq(PlayerState.money, 4200)
	AnimalState.unregister_housing(&"race_coop")

func test_general_store_reuses_shop_service_for_animals() -> void:
	var shop := ContentDB.get_shop(&"general_store")
	assert_not_null(shop)
	assert_true(shop.has_animal(&"chicken"))
	assert_true(shop.has_animal(&"cow"))
	assert_true(shop.has_animal(&"pig"))
	var money_before := PlayerState.money
	var instance_id := ShopState.buy_animal(shop, &"cow", &"starter_town")
	assert_ne(instance_id, &"")
	assert_eq(PlayerState.money, money_before - ContentDB.get_farm_animal(&"cow").purchase_price)
	assert_eq(AnimalState.get_housing_occupancy(&"starter_barn"), 2)
	money_before = PlayerState.money
	var pig_id := ShopState.buy_animal(shop, &"pig", &"starter_town")
	assert_ne(pig_id, &"")
	assert_eq(PlayerState.money, money_before - ContentDB.get_farm_animal(&"pig").purchase_price)
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

func test_loaded_animal_state_clamps_future_daily_markers() -> void:
	WorldClock.set_time(10, 8 * 60)
	var data := ContentDB.get_farm_animal(&"chicken")
	assert_not_null(data)
	if data == null:
		return
	var animal_scene := load("res://gamebase/modules/lifesim/animals/farm_animal.tscn") as PackedScene
	var chicken := animal_scene.instantiate() as FarmAnimal
	chicken.data = data
	chicken.persistent_id = &""
	add_child_autofree(chicken)
	chicken.load_state_data({
		"happiness": 999,
		"last_product_day": 999999,
		"last_pet_day": 999999,
		"last_fed_day": 999999,
		"last_processed_day": 999999,
	}, false)
	assert_eq(chicken.happiness, 100)
	assert_eq(chicken.last_product_day, 10)
	assert_eq(chicken.last_pet_day, 10)
	assert_eq(chicken.last_fed_day, 10)
	assert_eq(chicken.last_processed_day, 10)
	assert_true(chicken.is_fed_today())

func test_pig_uses_real_sheet_layout_and_truffle_interval() -> void:
	var pig_data := ContentDB.get_farm_animal(&"pig")
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

	var animal_scene := load("res://gamebase/modules/lifesim/animals/farm_animal.tscn") as PackedScene
	var pig := animal_scene.instantiate() as FarmAnimal
	pig.data = pig_data
	pig.persistent_id = &"test_pig_production"
	add_child_autofree(pig)
	await get_tree().process_frame
	assert_true(pig.is_product_ready())
	pig.get_node("Interactable").interact(null)
	assert_eq(InventoryState.get_quantity(&"truffle"), 1)
	assert_false(pig.is_product_ready())
	WorldClock.set_time(2, 8 * 60)
	await get_tree().process_frame
	assert_false(pig.is_product_ready())
	WorldClock.set_time(3, 8 * 60)
	await get_tree().process_frame
	assert_false(pig.is_product_ready())
	pig.last_fed_day = WorldClock.day
	assert_true(pig.is_product_ready())

func test_multi_product_collection_waits_until_the_full_output_fits() -> void:
	var chicken_data := ContentDB.get_farm_animal(&"chicken")
	assert_not_null(chicken_data)
	if chicken_data == null:
		return
	var original_quantity := chicken_data.product_quantity
	chicken_data.product_quantity = 2
	WorldState.set_value(&"animal:test_multi_product", {
		"happiness": 50,
		"last_product_day": 0,
		"last_pet_day": 0,
		"last_fed_day": 1,
		"last_processed_day": 1,
	})
	var animal_scene := load("res://gamebase/modules/lifesim/animals/farm_animal.tscn") as PackedScene
	var chicken := animal_scene.instantiate() as FarmAnimal
	chicken.data = chicken_data
	chicken.persistent_id = &"test_multi_product"
	add_child_autofree(chicken)
	await get_tree().process_frame
	assert_true(chicken.is_product_ready())

	InventoryState.clear()
	InventoryState.max_slots = 1
	InventoryState.add_item_by_id(&"egg", 23)
	chicken.get_node("Interactable").interact(null)
	assert_eq(InventoryState.get_quantity(&"egg"), 23)
	assert_true(chicken.is_product_ready())
	assert_eq(chicken.last_product_day, 0)

	assert_true(InventoryState.remove_item(&"egg", 1))
	chicken.get_node("Interactable").interact(null)
	assert_eq(InventoryState.get_quantity(&"egg"), 24)
	assert_false(chicken.is_product_ready())
	assert_eq(chicken.last_product_day, WorldClock.day)
	chicken_data.product_quantity = original_quantity

func test_product_collection_blocks_item_added_reentrancy() -> void:
	WorldState.set_value(&"animal:test_product_reentrancy", {
		"happiness": 50,
		"last_product_day": 0,
		"last_pet_day": 0,
		"last_fed_day": WorldClock.day,
		"last_processed_day": WorldClock.day,
	})
	var animal_scene := load("res://gamebase/modules/lifesim/animals/farm_animal.tscn") as PackedScene
	var chicken := animal_scene.instantiate() as FarmAnimal
	chicken.data = ContentDB.get_farm_animal(&"chicken")
	chicken.persistent_id = &"test_product_reentrancy"
	add_child_autofree(chicken)
	await get_tree().process_frame
	assert_true(chicken.is_product_ready())
	var observed := {"entered": false}
	var listener := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"egg" or bool(observed["entered"]):
			return
		observed["entered"] = true
		chicken.get_node("Interactable").interact(null)
	InventoryState.item_added.connect(listener)
	chicken.get_node("Interactable").interact(null)
	if InventoryState.item_added.is_connected(listener):
		InventoryState.item_added.disconnect(listener)
	assert_true(bool(observed["entered"]))
	assert_eq(InventoryState.get_quantity(&"egg"), 1)
	assert_eq(chicken.last_product_day, WorldClock.day)
	assert_false(chicken.is_product_ready())

func test_feed_housing_consumes_one_hay_per_unfed_animal_and_is_idempotent() -> void:
	WorldState.set_value(&"animal:starter_chicken_01", {
		"happiness": 50,
		"last_product_day": 1,
		"last_pet_day": 1,
		"last_fed_day": 1,
		"last_processed_day": 1,
	})
	InventoryState.add_item_by_id(&"hay", 2)
	WorldClock.set_time(2, 8 * 60)
	assert_eq(AnimalState.get_unfed_count(&"starter_coop"), 1)
	assert_eq(AnimalState.feed_housing(&"starter_coop"), 1)
	assert_eq(InventoryState.get_quantity(&"hay"), 1)
	assert_eq(AnimalState.get_unfed_count(&"starter_coop"), 0)
	assert_eq(AnimalState.feed_housing(&"starter_coop"), 0)
	assert_eq(InventoryState.get_quantity(&"hay"), 1)

func test_housings_name_themselves_and_report_what_their_animals_eat() -> void:
	assert_eq(AnimalState.get_housing_ids(&"starter_town"), [&"starter_coop", &"starter_barn"] as Array[StringName])
	assert_eq(AnimalState.get_housing_name(&"starter_barn"), "Barn")
	assert_eq(AnimalState.get_feed_item_ids(&"starter_town"), [&"hay"] as Array[StringName])
	assert_true(AnimalState.get_feed_needs(&"starter_coop").is_empty())
	WorldState.set_value(&"animal:starter_chicken_01", {"happiness": 50, "last_product_day": 1, "last_pet_day": 1, "last_fed_day": 1, "last_processed_day": 1})
	WorldClock.set_time(2, 8 * 60)
	assert_eq(AnimalState.get_feed_needs(&"starter_coop"), {&"hay": 1} as Dictionary[StringName, int])
	assert_eq(AnimalState.feed_housing(&"starter_coop"), 0, "No hay in the inventory")

func test_feed_housing_blocks_item_removed_reentrancy() -> void:
	WorldState.set_value(&"animal:starter_chicken_01", {
		"happiness": 50,
		"last_product_day": 1,
		"last_pet_day": 1,
		"last_fed_day": 1,
		"last_processed_day": 1,
	})
	WorldClock.set_time(2, 8 * 60)
	InventoryState.add_item_by_id(&"hay", 2)
	var observed := {"entered": false, "inner_fed": -1}
	var listener := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"hay" or bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_fed"] = AnimalState.feed_housing(&"starter_coop")
	InventoryState.item_removed.connect(listener)
	assert_eq(AnimalState.feed_housing(&"starter_coop"), 1)
	if InventoryState.item_removed.is_connected(listener):
		InventoryState.item_removed.disconnect(listener)
	assert_true(bool(observed["entered"]))
	assert_eq(int(observed["inner_fed"]), 0)
	assert_eq(InventoryState.get_quantity(&"hay"), 1)
	assert_eq(AnimalState.get_unfed_count(&"starter_coop"), 0)

func test_animal_offline_catchup_penalizes_missed_feed_and_feeding_restores_production() -> void:
	WorldState.set_value(&"animal:starter_chicken_01", {
		"happiness": 60,
		"last_product_day": 1,
		"last_pet_day": 1,
		"last_fed_day": 1,
		"last_processed_day": 1,
	})
	WorldClock.set_time(4, 8 * 60)
	var animal_scene := load("res://gamebase/modules/lifesim/animals/farm_animal.tscn") as PackedScene
	var chicken := animal_scene.instantiate() as FarmAnimal
	chicken.data = ContentDB.get_farm_animal(&"chicken")
	chicken.persistent_id = &"starter_chicken_01"
	add_child_autofree(chicken)
	await get_tree().process_frame
	assert_eq(chicken.happiness, 52)
	assert_false(chicken.is_fed_today())
	assert_false(chicken.is_product_ready())
	InventoryState.add_item_by_id(&"hay", 1)
	assert_eq(AnimalState.feed_housing(&"starter_coop"), 1)
	await get_tree().process_frame
	assert_true(chicken.is_fed_today())
	assert_true(chicken.is_product_ready())
	assert_eq(InventoryState.get_quantity(&"hay"), 0)

func test_animal_catchup_handles_extreme_day_jump_without_per_day_iteration() -> void:
	var animal_scene := load("res://gamebase/modules/lifesim/animals/farm_animal.tscn") as PackedScene
	var chicken := animal_scene.instantiate() as FarmAnimal
	chicken.data = ContentDB.get_farm_animal(&"chicken")
	chicken.persistent_id = &""
	add_child_autofree(chicken)
	await get_tree().process_frame
	chicken.happiness = 60
	chicken.last_pet_day = 1
	chicken.last_fed_day = 1
	chicken.last_processed_day = 1
	chicken.call("_advance_to_day", 1_000_000)
	assert_eq(chicken.last_processed_day, 1_000_000)
	assert_eq(chicken.happiness, 0)

func test_animal_catchup_commits_processed_day_before_happiness_signal_reentrancy() -> void:
	WorldState.set_value(&"animal:test_catchup_reentrancy", {
		"happiness": 60,
		"last_product_day": 1,
		"last_pet_day": 1,
		"last_fed_day": 1,
		"last_processed_day": 1,
	})
	var animal_scene := load("res://gamebase/modules/lifesim/animals/farm_animal.tscn") as PackedScene
	var chicken := animal_scene.instantiate() as FarmAnimal
	chicken.data = ContentDB.get_farm_animal(&"chicken")
	chicken.persistent_id = &"test_catchup_reentrancy"
	add_child_autofree(chicken)
	await get_tree().process_frame
	var entered := {"value": false}
	var advance_again := func(_happiness: int) -> void:
		if bool(entered["value"]):
			return
		entered["value"] = true
		WorldClock.set_time(4, 8 * 60)
	chicken.happiness_changed.connect(advance_again)
	WorldClock.set_time(3, 8 * 60)
	if chicken.happiness_changed.is_connected(advance_again):
		chicken.happiness_changed.disconnect(advance_again)
	assert_true(bool(entered["value"]))
	assert_eq(WorldClock.day, 4)
	assert_eq(chicken.last_processed_day, 4)
	assert_eq(chicken.happiness, 52)

func test_animals_can_be_renamed_and_sold_with_half_price_refund() -> void:
	var instance_id := AnimalState.purchase(&"chicken", &"starter_town")
	assert_ne(instance_id, &"")
	assert_true(AnimalState.rename_animal(instance_id, "Pip"))
	assert_false(AnimalState.rename_animal(instance_id, ""))
	var record := AnimalState.get_record(instance_id)
	assert_eq(String(record.get("custom_name", "")), "Pip")
	var money_before_sale := PlayerState.money
	var expected_refund := int(round(float(ContentDB.get_farm_animal(&"chicken").purchase_price) * 0.5))
	var refund := AnimalState.sell_animal(instance_id)
	assert_eq(refund, expected_refund)
	assert_eq(PlayerState.money, money_before_sale + expected_refund)
	assert_true(AnimalState.get_record(instance_id).is_empty())
	assert_eq(AnimalState.get_housing_occupancy(&"starter_coop"), 1)
	assert_eq(WorldState.get_value(StringName("animal:%s" % String(instance_id)), null), null)

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
	var chicken_data := ContentDB.get_farm_animal(&"chicken")
	var cow_data := ContentDB.get_farm_animal(&"cow")
	var pig_data := ContentDB.get_farm_animal(&"pig")
	assert_eq(chicken_data.get_product_item_id(79), &"egg")
	assert_eq(chicken_data.get_product_item_id(80), &"large_egg")
	assert_eq(cow_data.get_product_item_id(80), &"large_milk")
	assert_eq(pig_data.get_product_item_id(84), &"truffle")
	assert_eq(pig_data.get_product_item_id(85), &"prime_truffle")
	assert_gt(ContentDB.get_item(&"large_egg").sell_price, ContentDB.get_item(&"egg").sell_price)
	assert_gt(ContentDB.get_item(&"large_milk").sell_price, ContentDB.get_item(&"milk").sell_price)
	assert_gt(ContentDB.get_item(&"prime_truffle").sell_price, ContentDB.get_item(&"truffle").sell_price)

	WorldState.set_value(&"animal:test_happy_chicken", {
		"happiness": 85,
		"last_product_day": 0,
		"last_pet_day": 0,
		"last_fed_day": 1,
		"last_processed_day": 1,
	})
	var animal_scene := load("res://gamebase/modules/lifesim/animals/farm_animal.tscn") as PackedScene
	var chicken := animal_scene.instantiate() as FarmAnimal
	chicken.data = chicken_data
	chicken.persistent_id = &"test_happy_chicken"
	add_child_autofree(chicken)
	await get_tree().process_frame
	assert_true(chicken.is_product_ready())
	chicken.get_node("Interactable").interact(null)
	assert_eq(InventoryState.get_quantity(&"large_egg"), 1)
	assert_eq(InventoryState.get_quantity(&"egg"), 0)

func test_animal_name_typed_by_the_player_is_shown_as_plain_text() -> void:
	assert_true(AnimalState.rename_animal(&"starter_chicken_01", "[i]Bessie[/i]"))
	var menu := (load("res://gamebase/modules/lifesim/animals/animal_management_menu.tscn") as PackedScene).instantiate()
	add_child_autofree(menu)
	await get_tree().process_frame
	menu.open(&"starter_town")
	get_tree().paused = false
	var details := menu.get_node("Panel/VBox/Details") as RichTextLabel
	assert_true(details.text.contains("[lb]i]Bessie[lb]/i]"), details.text)
	assert_true(details.get_parsed_text().contains("[i]Bessie[/i]"), details.get_parsed_text())
