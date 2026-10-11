extends GutTest

## Farm1's coop and barn expansions: their tiers, costs and the town projects
## that unlock them. How expansions are bought is tested with the lifesim module.

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
	PlayerState.money = 50000
	AnimalState.register_housing(&"starter_coop", &"starter_town", &"coop", 4, "Coop")
	AnimalState.register_housing(&"starter_barn", &"starter_town", &"barn", 4, "Barn")
	AnimalState.reset_new_game()

func after_each() -> void:
	AnimalState.unregister_housing(&"starter_coop")
	AnimalState.unregister_housing(&"starter_barn")
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)

func test_expansion_catalog_is_registered() -> void:
	assert_eq(FarmExpansionData.find_all().size(), 4)
	assert_not_null(FarmExpansionData.find(&"big_coop"))
	assert_not_null(FarmExpansionData.find(&"deluxe_barn"))

func test_coop_expands_from_four_to_eight_to_twelve_after_the_garden_and_workshop_projects() -> void:
	assert_eq(AnimalState.get_housing_capacity(&"starter_coop"), 4)
	assert_false(FarmExpansionState.is_available(&"big_coop"))
	WorldState.set_value(&"project:starter_garden:complete", true)
	InventoryState.add_item_by_id(&"wood", 30)
	InventoryState.add_item_by_id(&"stone", 10)
	var money_before := PlayerState.money
	assert_true(FarmExpansionState.is_available(&"big_coop"))
	assert_true(FarmExpansionState.purchase(&"big_coop"))
	assert_eq(PlayerState.money, money_before - 2000)
	assert_eq(InventoryState.get_quantity(&"wood"), 0)
	assert_eq(InventoryState.get_quantity(&"stone"), 0)
	assert_eq(AnimalState.get_housing_capacity(&"starter_coop"), 8)

	assert_false(FarmExpansionState.is_available(&"deluxe_coop"))
	WorldState.set_value(&"project:riverside_workshop:complete", true)
	InventoryState.add_item_by_id(&"wood", 50)
	InventoryState.add_item_by_id(&"iron_bar", 3)
	InventoryState.add_item_by_id(&"gold_bar", 1)
	assert_true(FarmExpansionState.is_available(&"deluxe_coop"))
	assert_true(FarmExpansionState.purchase(&"deluxe_coop"))
	assert_eq(AnimalState.get_housing_capacity(&"starter_coop"), 12)

func test_deluxe_barn_requires_the_big_barn_and_the_riverside_workshop() -> void:
	WorldState.set_value(&"project:starter_garden:complete", true)
	WorldState.set_value(&"project:riverside_workshop:complete", true)
	assert_false(FarmExpansionState.is_available(&"deluxe_barn"))
	InventoryState.add_item_by_id(&"wood", 40)
	InventoryState.add_item_by_id(&"stone", 20)
	assert_true(FarmExpansionState.purchase(&"big_barn"))
	assert_eq(AnimalState.get_housing_capacity(&"starter_barn"), 8)
	assert_true(FarmExpansionState.is_available(&"deluxe_barn"))
	WorldState.set_value(&"project:riverside_workshop:complete", false)
	assert_false(FarmExpansionState.is_available(&"deluxe_barn"))
