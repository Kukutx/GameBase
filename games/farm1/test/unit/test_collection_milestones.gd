extends GutTest

## Farm1's archive milestones. How milestones become ready and are claimed is
## tested with the progression module.

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
	assert_eq(CollectionMilestoneData.find_all().size(), 4)
	for milestone_id: StringName in [&"crop_archive", &"fish_archive", &"mineral_archive", &"animal_archive"]:
		assert_not_null(CollectionMilestoneData.find(milestone_id))
	var menu_scene := load("res://game/ui/game_menu.tscn") as PackedScene
	var menu := menu_scene.instantiate()
	autofree(menu)
	assert_not_null(menu.get_node_or_null("Panel/Layout/CollectionClaim"))

func test_completing_the_crop_archive_pays_500g_and_six_tomato_seeds() -> void:
	for item_id: StringName in CollectionState.get_total_ids(CollectionService.CROPS):
		CollectionState.record(CollectionService.CROPS, item_id, 1)
	assert_true(CollectionMilestones.is_ready(&"crop_archive"))
	var money_before := PlayerState.money
	assert_true(CollectionMilestones.claim(&"crop_archive"))
	assert_eq(PlayerState.money, money_before + 500)
	assert_eq(InventoryState.get_quantity(&"tomato_seeds"), 6)

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
		LifesimEvents.animal_product_collected.emit(&"test_animal", item_id, 1)
	assert_eq(CollectionState.get_discovered_count(CollectionService.ANIMAL_PRODUCTS), 3)
	assert_false(CollectionMilestones.is_ready(&"animal_archive"))
	for item_id: StringName in [&"large_egg", &"large_milk", &"prime_truffle"]:
		LifesimEvents.animal_product_collected.emit(&"test_animal", item_id, 1)
	assert_eq(CollectionState.get_discovered_count(CollectionService.ANIMAL_PRODUCTS), 6)
	assert_true(CollectionMilestones.is_ready(&"animal_archive"))
