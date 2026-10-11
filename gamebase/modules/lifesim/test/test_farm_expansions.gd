extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

var _world_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	ContentFixture.use(self, _fixture_content())
	WorldState.clear()
	InventoryState.clear()
	PlayerState.reset_new_game()
	PlayerState.money = 50000
	AnimalState.register_housing(&"fixture_coop", &"fixture_farm", &"fixture_poultry", 4, "Coop")
	AnimalState.register_housing(&"fixture_barn", &"fixture_farm", &"fixture_livestock", 4, "Barn")
	AnimalState.reset_new_game()
	AnimalState.grant_animal(&"fixture_hen_01", &"fixture_hen", &"fixture_farm", &"fixture_coop", 0)

func after_each() -> void:
	# GUT frees the fixture content only after this method: restore the
	# services with the game's content, which their snapshots name.
	ContentRegistry.active = ContentDB
	AnimalState.unregister_housing(&"fixture_coop")
	AnimalState.unregister_housing(&"fixture_barn")
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)

func test_animal_ledger_has_a_feed_and_an_expansion_button_per_housing() -> void:
	var menu_scene := load("res://gamebase/modules/lifesim/animals/animal_management_menu.tscn") as PackedScene
	var menu := menu_scene.instantiate() as AnimalManagementMenu
	add_child_autofree(menu)
	InventoryState.add_item_by_id(&"fixture_fodder", 3)
	menu.open(&"fixture_farm")
	var feed_buttons := menu.get_node("Panel/VBox/FeedRow").get_children()
	var expansion_buttons := menu.get_node("Panel/VBox/ExpansionRow").get_children()
	menu.close()
	assert_eq(feed_buttons.size(), 2)
	assert_eq(expansion_buttons.size(), 2)
	assert_eq((feed_buttons[0] as Button).text, "Feed Coop (0)")
	assert_eq((feed_buttons[1] as Button).text, "Feed Barn (0)")
	assert_true((feed_buttons[0] as Button).disabled, "The granted hen is already fed")
	assert_eq((menu.get_node("Panel/VBox/Summary") as Label).text, "Coop 1/4 · Barn 0/4 · Hay 3")

func test_coop_expands_from_four_to_eight_to_twelve_and_persists() -> void:
	assert_eq(AnimalState.get_housing_capacity(&"fixture_coop"), 4)
	WorldState.set_value(&"fixture_garden_restored", true)
	InventoryState.add_item_by_id(&"fixture_timber", 30)
	InventoryState.add_item_by_id(&"fixture_rock_chunk", 10)
	var money_before := PlayerState.money
	assert_true(FarmExpansionState.is_available(&"fixture_big_coop"))
	assert_true(FarmExpansionState.purchase(&"fixture_big_coop"))
	assert_eq(PlayerState.money, money_before - 2000)
	assert_eq(InventoryState.get_quantity(&"fixture_timber"), 0)
	assert_eq(InventoryState.get_quantity(&"fixture_rock_chunk"), 0)
	assert_eq(AnimalState.get_housing_capacity(&"fixture_coop"), 8)

	WorldState.set_value(&"fixture_workshop_built", true)
	InventoryState.add_item_by_id(&"fixture_timber", 50)
	InventoryState.add_item_by_id(&"fixture_metal_bar", 3)
	assert_true(FarmExpansionState.is_available(&"fixture_deluxe_coop"))
	assert_true(FarmExpansionState.purchase(&"fixture_deluxe_coop"))
	assert_eq(AnimalState.get_housing_capacity(&"fixture_coop"), 12)
	assert_eq(AnimalState.get_available_slots(&"fixture_farm", &"fixture_poultry"), 11)

	var saved := WorldState.to_save_data()
	WorldState.clear()
	assert_false(FarmExpansionState.is_completed(&"fixture_big_coop"))
	WorldState.load_save_data(saved)
	assert_true(FarmExpansionState.is_completed(&"fixture_big_coop"))
	assert_true(FarmExpansionState.is_completed(&"fixture_deluxe_coop"))
	assert_eq(AnimalState.get_housing_capacity(&"fixture_coop"), 12)

func test_expansion_state_ignores_malformed_completion_values() -> void:
	WorldState.set_value(FarmExpansionService.STATE_KEY, {"fixture_big_coop": {"bad": true}})
	assert_false(FarmExpansionState.is_completed(&"fixture_big_coop"))
	assert_eq(AnimalState.get_housing_capacity(&"fixture_coop"), 4)
	WorldState.set_value(FarmExpansionService.STATE_KEY, {"fixture_big_coop": true})
	assert_true(FarmExpansionState.is_completed(&"fixture_big_coop"))
	assert_eq(AnimalState.get_housing_capacity(&"fixture_coop"), 8)

func test_expansion_purchase_blocks_item_removed_reentrancy() -> void:
	WorldState.set_value(&"fixture_garden_restored", true)
	InventoryState.add_item_by_id(&"fixture_timber", 30)
	InventoryState.add_item_by_id(&"fixture_rock_chunk", 10)
	var money_before := PlayerState.money
	var observed := {"entered": false, "inner_result": true}
	var reenter := func(_item_id: StringName, _quantity: int) -> void:
		if bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_result"] = FarmExpansionState.purchase(&"fixture_big_coop")
	InventoryState.item_removed.connect(reenter)
	assert_true(FarmExpansionState.purchase(&"fixture_big_coop"))
	if InventoryState.item_removed.is_connected(reenter):
		InventoryState.item_removed.disconnect(reenter)
	assert_true(bool(observed["entered"]))
	assert_false(bool(observed["inner_result"]))
	assert_true(FarmExpansionState.is_completed(&"fixture_big_coop"))
	assert_eq(InventoryState.get_quantity(&"fixture_timber"), 0)
	assert_eq(InventoryState.get_quantity(&"fixture_rock_chunk"), 0)
	assert_eq(PlayerState.money, money_before - 2000)

func test_expansion_material_commit_is_atomic_before_inventory_listeners_run() -> void:
	WorldState.set_value(&"fixture_garden_restored", true)
	InventoryState.add_item_by_id(&"fixture_timber", 30)
	InventoryState.add_item_by_id(&"fixture_rock_chunk", 10)
	var money_before := PlayerState.money
	var observed := {"signals": 0, "final_state": true}
	var listener := func(_item_id: StringName, _quantity: int) -> void:
		observed["signals"] = int(observed["signals"]) + 1
		observed["final_state"] = bool(observed["final_state"]) and InventoryState.get_quantity(&"fixture_timber") == 0 and InventoryState.get_quantity(&"fixture_rock_chunk") == 0
	InventoryState.item_removed.connect(listener)
	assert_true(FarmExpansionState.purchase(&"fixture_big_coop"))
	if InventoryState.item_removed.is_connected(listener):
		InventoryState.item_removed.disconnect(listener)
	assert_eq(int(observed["signals"]), 2)
	assert_true(bool(observed["final_state"]))
	assert_eq(InventoryState.get_quantity(&"fixture_timber"), 0)
	assert_eq(InventoryState.get_quantity(&"fixture_rock_chunk"), 0)
	assert_eq(PlayerState.money, money_before - 2000)
	assert_true(FarmExpansionState.is_completed(&"fixture_big_coop"))
	assert_eq(AnimalState.get_housing_capacity(&"fixture_coop"), 8)

func test_deluxe_expansion_requires_previous_tier_and_its_world_flag() -> void:
	WorldState.set_value(&"fixture_garden_restored", true)
	WorldState.set_value(&"fixture_workshop_built", true)
	assert_false(FarmExpansionState.is_available(&"fixture_deluxe_barn"))
	InventoryState.add_item_by_id(&"fixture_timber", 40)
	InventoryState.add_item_by_id(&"fixture_rock_chunk", 20)
	assert_true(FarmExpansionState.purchase(&"fixture_big_barn"))
	assert_true(FarmExpansionState.is_available(&"fixture_deluxe_barn"))
	assert_eq(AnimalState.get_housing_capacity(&"fixture_barn"), 8)

# A hen and a cow that eat hay, and two expansion tiers for each housing: the
# first behind one world flag, the second behind the first and another flag.
func _fixture_content() -> Array:
	var entries: Array = [
		_item(&"fixture_timber", "Timber"),
		_item(&"fixture_rock_chunk", "Rock Chunk"),
		_item(&"fixture_metal_bar", "Metal Bar"),
		_item(&"fixture_fodder", "Hay"),
		_animal(&"fixture_hen", "Hen", &"fixture_poultry"),
		_animal(&"fixture_cow", "Cow", &"fixture_livestock"),
		_expansion(&"fixture_big_coop", &"fixture_coop", 8, 2000,
			{"fixture_timber": 30, "fixture_rock_chunk": 10}, [], &"fixture_garden_restored"),
		_expansion(&"fixture_deluxe_coop", &"fixture_coop", 12, 6000,
			{"fixture_timber": 50, "fixture_metal_bar": 3}, [&"fixture_big_coop"], &"fixture_workshop_built"),
		_expansion(&"fixture_big_barn", &"fixture_barn", 8, 3000,
			{"fixture_timber": 40, "fixture_rock_chunk": 20}, [], &"fixture_garden_restored"),
		_expansion(&"fixture_deluxe_barn", &"fixture_barn", 12, 8000,
			{"fixture_timber": 60, "fixture_metal_bar": 4}, [&"fixture_big_barn"], &"fixture_workshop_built"),
	]
	return entries

func _item(id: StringName, display_name: String) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = display_name
	return item

func _animal(id: StringName, display_name: String, housing_type: StringName) -> FarmAnimalData:
	var animal := FarmAnimalData.new()
	animal.id = id
	animal.display_name = display_name
	animal.housing_type = housing_type
	animal.feed_item_id = &"fixture_fodder"
	return animal

func _expansion(id: StringName, housing_id: StringName, capacity_after: int, money_cost: int,
		materials: Dictionary, prerequisites: Array[StringName], required_world_flag: StringName) -> FarmExpansionData:
	var expansion := FarmExpansionData.new()
	expansion.id = id
	expansion.display_name = String(id).capitalize()
	expansion.housing_id = housing_id
	expansion.capacity_after = capacity_after
	expansion.money_cost = money_cost
	expansion.materials = materials
	expansion.prerequisites = prerequisites
	expansion.required_world_flag = required_world_flag
	return expansion
