extends GutTest

## Farm1's three town projects and the towns that show them. How projects take
## donations and pay out is tested with the progression module.

var _world_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _vitals_snapshot: Dictionary
var _hotbar_snapshot: Dictionary

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = Wallet.to_save_data()
	_vitals_snapshot = Vitals.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	WorldState.clear()
	InventoryState.clear()
	Wallet.reset_new_game()
	Vitals.reset_new_game()

func after_each() -> void:
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	Wallet.load_save_data(_player_snapshot)
	Vitals.load_save_data(_vitals_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)

func test_project_chain_donates_materials_unlocks_the_next_and_rewards_once() -> void:
	assert_false(TownProjects.is_available(&"riverside_workshop_fund"))
	assert_false(TownProjects.is_available(&"harbor_supply_drive"))

	for item_id: StringName in [&"turnip", &"carrot", &"potato"]:
		InventoryState.add_item_by_id(item_id, 3)
	InventoryState.add_item_by_id(&"wood", 10)
	assert_eq(TownProjects.contribute_all_available(&"starter_garden_restoration"), 19)
	assert_true(TownProjects.is_completed(&"starter_garden_restoration"))
	assert_true(TownProjects.is_available(&"riverside_workshop_fund"))
	var money_before := Wallet.money
	assert_true(TownProjects.claim_reward(&"starter_garden_restoration"))
	assert_eq(Wallet.money, money_before + 600)
	assert_eq(InventoryState.get_quantity(&"tomato_seeds"), 6)
	assert_false(TownProjects.claim_reward(&"starter_garden_restoration"))

	InventoryState.add_item_by_id(&"copper_bar", 3)
	InventoryState.add_item_by_id(&"stone", 12)
	InventoryState.add_item_by_id(&"wood", 15)
	assert_eq(TownProjects.contribute_all_available(&"riverside_workshop_fund"), 30)
	assert_true(TownProjects.is_completed(&"riverside_workshop_fund"))
	assert_true(TownProjects.is_available(&"harbor_supply_drive"))
	assert_true(TownProjects.claim_reward(&"riverside_workshop_fund"))
	assert_eq(InventoryState.get_quantity(&"oil_maker"), 1)

	InventoryState.add_item_by_id(&"sardine", 2)
	InventoryState.add_item_by_id(&"seaweed", 4)
	InventoryState.add_item_by_id(&"egg", 2)
	InventoryState.add_item_by_id(&"milk", 2)
	assert_eq(TownProjects.contribute_all_available(&"harbor_supply_drive"), 10)
	assert_true(TownProjects.is_completed(&"harbor_supply_drive"))
	assert_true(TownProjects.claim_reward(&"harbor_supply_drive"))
	assert_eq(InventoryState.get_quantity(&"fish_soup"), 2)

func test_all_three_towns_expose_project_board_and_progress_visual() -> void:
	var cases := {
		"res://game/world/dev_world.tscn": ["TownProjectBoard", "CommunityGardenProgress"],
		"res://game/world/riverside_town.tscn": ["TownProjectBoard", "WorkshopProgress"],
		"res://game/world/harbor_town.tscn": ["TownProjectBoard", "HarborSupplyProgress"],
	}
	for scene_path: String in cases.keys():
		var packed := load(scene_path) as PackedScene
		assert_not_null(packed)
		var scene := packed.instantiate()
		add_child_autofree(scene)
		await get_tree().process_frame
		for node_name: String in cases[scene_path]:
			assert_not_null(scene.get_node_or_null(node_name), "%s missing %s" % [scene_path, node_name])
