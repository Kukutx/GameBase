extends GutTest

# Farm1's sprinkler. Placing, packing up and the daily effects of placeables
# are tested on fixture content in gamebase/modules/items/test/ and
# gamebase/modules/lifesim/test/ (test_building_automation.gd).

var _world_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _skills_snapshot: Dictionary
var _hotbar_snapshot: Dictionary

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_skills_snapshot = Skills.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	WorldState.clear()
	InventoryState.clear()
	Skills.reset_new_game()

func after_each() -> void:
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	Skills.load_save_data(_skills_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)

func test_sprinkler_is_craftable_and_waters_around_itself_on_the_farm() -> void:
	assert_not_null(PlaceableData.find(&"basic_sprinkler"))
	assert_not_null(CraftingState.get_recipe(&"basic_sprinkler"))
	InventoryState.add_item_by_id(&"copper_bar", 1)
	InventoryState.add_item_by_id(&"wood", 2)
	assert_true(CraftingState.craft(&"basic_sprinkler"))
	assert_eq(InventoryState.get_quantity(&"basic_sprinkler"), 1)

	var record := BuildingState.place_from_inventory(&"basic_sprinkler", &"starter_town", Vector2(0, 0))
	assert_false(record.is_empty())
	assert_true(BuildingState.is_point_affected(&"starter_town", &"water", Vector2(40, 0)))
	assert_false(BuildingState.is_point_affected(&"starter_town", &"water", Vector2(100, 0)))
