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
	PlayerState.money = 50000
	AnimalState.register_housing(&"starter_coop", &"starter_town", &"coop", 4)
	AnimalState.register_housing(&"starter_barn", &"starter_town", &"barn", 4)
	AnimalState.reset_new_game()
	AnimalState.grant_animal(&"starter_chicken_01", &"chicken", &"starter_town", &"starter_coop", 0)

func after_each() -> void:
	AnimalState.unregister_housing(&"starter_coop")
	AnimalState.unregister_housing(&"starter_barn")
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)

func test_expansion_catalog_and_animal_ledger_controls_are_registered() -> void:
	assert_eq(ContentDB.get_all_farm_expansions().size(), 4)
	assert_not_null(ContentDB.get_farm_expansion(&"big_coop"))
	assert_not_null(ContentDB.get_farm_expansion(&"deluxe_barn"))
	var menu_scene := load("res://gamebase/modules/lifesim/animals/animal_management_menu.tscn") as PackedScene
	var menu := menu_scene.instantiate()
	autofree(menu)
	assert_not_null(menu.get_node_or_null("Panel/VBox/ExpansionRow/ExpandCoop"))
	assert_not_null(menu.get_node_or_null("Panel/VBox/ExpansionRow/ExpandBarn"))

func test_coop_expands_from_four_to_eight_to_twelve_and_persists() -> void:
	assert_eq(AnimalState.get_housing_capacity(&"starter_coop"), 4)
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

	WorldState.set_value(&"project:riverside_workshop:complete", true)
	InventoryState.add_item_by_id(&"wood", 50)
	InventoryState.add_item_by_id(&"iron_bar", 3)
	InventoryState.add_item_by_id(&"gold_bar", 1)
	assert_true(FarmExpansionState.is_available(&"deluxe_coop"))
	assert_true(FarmExpansionState.purchase(&"deluxe_coop"))
	assert_eq(AnimalState.get_housing_capacity(&"starter_coop"), 12)
	assert_eq(AnimalState.get_available_slots(&"starter_town", &"coop"), 11)

	var saved := WorldState.to_save_data()
	WorldState.clear()
	assert_false(FarmExpansionState.is_completed(&"big_coop"))
	WorldState.load_save_data(saved)
	assert_true(FarmExpansionState.is_completed(&"big_coop"))
	assert_true(FarmExpansionState.is_completed(&"deluxe_coop"))
	assert_eq(AnimalState.get_housing_capacity(&"starter_coop"), 12)

func test_expansion_state_ignores_malformed_completion_values() -> void:
	WorldState.set_value(FarmExpansionService.STATE_KEY, {"big_coop": {"bad": true}})
	assert_false(FarmExpansionState.is_completed(&"big_coop"))
	assert_eq(AnimalState.get_housing_capacity(&"starter_coop"), 4)
	WorldState.set_value(FarmExpansionService.STATE_KEY, {"big_coop": true})
	assert_true(FarmExpansionState.is_completed(&"big_coop"))
	assert_eq(AnimalState.get_housing_capacity(&"starter_coop"), 8)

func test_expansion_purchase_blocks_item_removed_reentrancy() -> void:
	WorldState.set_value(&"project:starter_garden:complete", true)
	InventoryState.add_item_by_id(&"wood", 30)
	InventoryState.add_item_by_id(&"stone", 10)
	var money_before := PlayerState.money
	var observed := {"entered": false, "inner_result": true}
	var reenter := func(_item_id: StringName, _quantity: int) -> void:
		if bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_result"] = FarmExpansionState.purchase(&"big_coop")
	InventoryState.item_removed.connect(reenter)
	assert_true(FarmExpansionState.purchase(&"big_coop"))
	if InventoryState.item_removed.is_connected(reenter):
		InventoryState.item_removed.disconnect(reenter)
	assert_true(bool(observed["entered"]))
	assert_false(bool(observed["inner_result"]))
	assert_true(FarmExpansionState.is_completed(&"big_coop"))
	assert_eq(InventoryState.get_quantity(&"wood"), 0)
	assert_eq(InventoryState.get_quantity(&"stone"), 0)
	assert_eq(PlayerState.money, money_before - 2000)

func test_expansion_material_commit_is_atomic_before_inventory_listeners_run() -> void:
	WorldState.set_value(&"project:starter_garden:complete", true)
	InventoryState.add_item_by_id(&"wood", 30)
	InventoryState.add_item_by_id(&"stone", 10)
	var money_before := PlayerState.money
	var observed := {"signals": 0, "final_state": true}
	var listener := func(_item_id: StringName, _quantity: int) -> void:
		observed["signals"] = int(observed["signals"]) + 1
		observed["final_state"] = bool(observed["final_state"]) and InventoryState.get_quantity(&"wood") == 0 and InventoryState.get_quantity(&"stone") == 0
	InventoryState.item_removed.connect(listener)
	assert_true(FarmExpansionState.purchase(&"big_coop"))
	if InventoryState.item_removed.is_connected(listener):
		InventoryState.item_removed.disconnect(listener)
	assert_eq(int(observed["signals"]), 2)
	assert_true(bool(observed["final_state"]))
	assert_eq(InventoryState.get_quantity(&"wood"), 0)
	assert_eq(InventoryState.get_quantity(&"stone"), 0)
	assert_eq(PlayerState.money, money_before - 2000)
	assert_true(FarmExpansionState.is_completed(&"big_coop"))
	assert_eq(AnimalState.get_housing_capacity(&"starter_coop"), 8)

func test_deluxe_expansion_requires_previous_tier_and_riverside_project() -> void:
	WorldState.set_value(&"project:starter_garden:complete", true)
	WorldState.set_value(&"project:riverside_workshop:complete", true)
	assert_false(FarmExpansionState.is_available(&"deluxe_barn"))
	InventoryState.add_item_by_id(&"wood", 40)
	InventoryState.add_item_by_id(&"stone", 20)
	assert_true(FarmExpansionState.purchase(&"big_barn"))
	assert_true(FarmExpansionState.is_available(&"deluxe_barn"))
	assert_eq(AnimalState.get_housing_capacity(&"starter_barn"), 8)
