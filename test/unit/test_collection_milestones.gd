extends GutTest

var _world_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	WorldState.clear()
	InventoryState.clear()
	PlayerState.reset_new_game()

func after_each() -> void:
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)

func test_archive_milestones_are_registered_and_visible_in_game_menu() -> void:
	assert_eq(ContentDB.get_all_collection_milestones().size(), 4)
	for milestone_id: StringName in [&"crop_archive", &"fish_archive", &"mineral_archive", &"animal_archive"]:
		assert_not_null(ContentDB.get_collection_milestone(milestone_id))
	var menu_scene := load("res://game/ui/game_menu.tscn") as PackedScene
	var menu := menu_scene.instantiate()
	autofree(menu)
	assert_not_null(menu.get_node_or_null("Panel/Layout/CollectionClaim"))

func test_crop_archive_becomes_ready_claims_once_and_persists() -> void:
	for item_id: StringName in CollectionState.get_total_ids(CollectionService.CROPS):
		CollectionState.record(CollectionService.CROPS, item_id, 1)
	assert_true(CollectionMilestones.is_ready(&"crop_archive"))
	assert_eq(CollectionMilestones.get_ready_count(), 1)
	var money_before := PlayerState.money
	assert_true(CollectionMilestones.claim(&"crop_archive"))
	assert_true(CollectionMilestones.is_claimed(&"crop_archive"))
	assert_true(WorldState.get_bool(&"collection:crop_archive"))
	assert_eq(PlayerState.money, money_before + 500)
	assert_eq(InventoryState.get_quantity(&"tomato_seeds"), 6)
	assert_false(CollectionMilestones.claim(&"crop_archive"))

	var saved := WorldState.to_save_data()
	WorldState.clear()
	assert_false(CollectionMilestones.is_claimed(&"crop_archive"))
	WorldState.load_save_data(saved)
	assert_true(CollectionMilestones.is_claimed(&"crop_archive"))
	assert_false(CollectionMilestones.is_ready(&"crop_archive"))

func test_archive_claim_blocks_item_added_reentrancy() -> void:
	for item_id: StringName in CollectionState.get_total_ids(CollectionService.CROPS):
		CollectionState.record(CollectionService.CROPS, item_id, 1)
	assert_true(CollectionMilestones.is_ready(&"crop_archive"))
	var money_before := PlayerState.money
	var observed := {"entered": false, "inner_result": true}
	var listener := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"tomato_seeds" or bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_result"] = CollectionMilestones.claim(&"crop_archive")
	InventoryState.item_added.connect(listener)
	assert_true(CollectionMilestones.claim(&"crop_archive"))
	if InventoryState.item_added.is_connected(listener):
		InventoryState.item_added.disconnect(listener)
	assert_true(bool(observed["entered"]))
	assert_false(bool(observed["inner_result"]))
	assert_true(CollectionMilestones.is_claimed(&"crop_archive"))
	assert_eq(PlayerState.money, money_before + 500)
	assert_eq(InventoryState.get_quantity(&"tomato_seeds"), 6)

func test_ready_archive_grants_the_reward_promised_when_it_became_ready() -> void:
	for item_id: StringName in CollectionState.get_total_ids(CollectionService.CROPS):
		CollectionState.record(CollectionService.CROPS, item_id, 1)
	assert_true(CollectionMilestones.is_ready(&"crop_archive"))
	assert_true(WorldState.get_value(&"collection:milestone:crop_archive:reward_snapshot", {}) is Dictionary)
	WorldState.set_value(&"collection:milestone:crop_archive:reward_snapshot", {
		"items": {"wood": 2, "removed_item": 5},
		"money": 888,
	})
	var money_before := PlayerState.money
	assert_true(CollectionMilestones.claim(&"crop_archive"))
	assert_eq(PlayerState.money, money_before + 888)
	assert_eq(InventoryState.get_quantity(&"wood"), 2)
	assert_eq(InventoryState.get_quantity(&"removed_item"), 0)
	assert_eq(InventoryState.get_quantity(&"tomato_seeds"), 0)

func test_qualified_milestone_stays_claimable_after_catalog_growth() -> void:
	assert_eq(CollectionState.get_discovered_count(CollectionService.CROPS), 0)
	WorldState.set_value(&"collection:milestone_qualified:crop_archive", true)
	WorldState.set_value(&"collection:milestone:crop_archive:reward_snapshot", {
		"items": {"wood": 1},
		"money": 321,
	})
	assert_true(CollectionMilestones.is_ready(&"crop_archive"))
	var money_before := PlayerState.money
	assert_true(CollectionMilestones.claim(&"crop_archive"))
	assert_eq(PlayerState.money, money_before + 321)
	assert_eq(InventoryState.get_quantity(&"wood"), 1)

func test_mineral_archive_tracks_all_metal_tiers_through_iridium() -> void:
	var mineral_ids := CollectionState.get_total_ids(CollectionService.MINERALS)
	assert_true(mineral_ids.has(&"stone"))
	assert_true(mineral_ids.has(&"copper_ore"))
	assert_true(mineral_ids.has(&"iron_ore"))
	assert_true(mineral_ids.has(&"gold_ore"))
	assert_true(mineral_ids.has(&"iridium_ore"))
	for item_id: StringName in mineral_ids:
		CollectionState.record(CollectionService.MINERALS, item_id, 1)
	assert_true(CollectionMilestones.is_ready(&"mineral_archive"))

func test_rancher_archive_requires_premium_products_not_only_base_outputs() -> void:
	var animal_ids := CollectionState.get_total_ids(CollectionService.ANIMAL_PRODUCTS)
	assert_eq(animal_ids.size(), 6)
	for item_id: StringName in [&"egg", &"milk", &"truffle"]:
		GameEvents.animal_product_collected.emit(&"test_animal", item_id, 1)
	assert_eq(CollectionState.get_discovered_count(CollectionService.ANIMAL_PRODUCTS), 3)
	assert_false(CollectionMilestones.is_ready(&"animal_archive"))
	for item_id: StringName in [&"large_egg", &"large_milk", &"prime_truffle"]:
		GameEvents.animal_product_collected.emit(&"test_animal", item_id, 1)
	assert_eq(CollectionState.get_discovered_count(CollectionService.ANIMAL_PRODUCTS), 6)
	assert_true(CollectionMilestones.is_ready(&"animal_archive"))

func test_pure_prerequisite_milestones_require_claimed_dependencies() -> void:
	var milestone := CollectionMilestoneData.new()
	milestone.id = &"test_meta_archive"
	milestone.category = &""
	milestone.prerequisites = [&"crop_archive", &"fish_archive"]
	assert_false(bool(CollectionMilestones.call("_prerequisites_met", milestone)))
	WorldState.set_value(&"collection:milestone:crop_archive:claimed", true)
	assert_false(bool(CollectionMilestones.call("_prerequisites_met", milestone)))
	WorldState.set_value(&"collection:milestone:fish_archive:claimed", true)
	assert_true(bool(CollectionMilestones.call("_prerequisites_met", milestone)))
