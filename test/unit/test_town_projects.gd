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

func test_project_chain_donates_materials_unlocks_flags_and_rewards_once() -> void:
	assert_false(TownProjects.is_available(&"riverside_workshop_fund"))
	assert_false(TownProjects.is_available(&"harbor_supply_drive"))

	for item_id: StringName in [&"turnip", &"carrot", &"potato"]:
		InventoryState.add_item_by_id(item_id, 3)
	InventoryState.add_item_by_id(&"wood", 10)
	assert_eq(TownProjects.contribute_all_available(&"starter_garden_restoration"), 19)
	assert_true(TownProjects.is_completed(&"starter_garden_restoration"))
	assert_true(WorldState.get_bool(&"project:starter_garden:complete"))
	assert_true(TownProjects.is_available(&"riverside_workshop_fund"))
	var money_before := PlayerState.money
	assert_true(TownProjects.claim_reward(&"starter_garden_restoration"))
	assert_eq(PlayerState.money, money_before + 600)
	assert_eq(InventoryState.get_quantity(&"tomato_seeds"), 6)
	assert_false(TownProjects.claim_reward(&"starter_garden_restoration"))

	InventoryState.add_item_by_id(&"copper_bar", 3)
	InventoryState.add_item_by_id(&"stone", 12)
	InventoryState.add_item_by_id(&"wood", 15)
	assert_eq(TownProjects.contribute_all_available(&"riverside_workshop_fund"), 30)
	assert_true(TownProjects.is_completed(&"riverside_workshop_fund"))
	assert_true(WorldState.get_bool(&"project:riverside_workshop:complete"))
	assert_true(TownProjects.is_available(&"harbor_supply_drive"))
	assert_true(TownProjects.claim_reward(&"riverside_workshop_fund"))
	assert_eq(InventoryState.get_quantity(&"oil_maker"), 1)

	InventoryState.add_item_by_id(&"sardine", 2)
	InventoryState.add_item_by_id(&"seaweed", 4)
	InventoryState.add_item_by_id(&"egg", 2)
	InventoryState.add_item_by_id(&"milk", 2)
	assert_eq(TownProjects.contribute_all_available(&"harbor_supply_drive"), 10)
	assert_true(TownProjects.is_completed(&"harbor_supply_drive"))
	assert_true(WorldState.get_bool(&"project:harbor_supply:complete"))
	assert_true(TownProjects.claim_reward(&"harbor_supply_drive"))
	assert_eq(InventoryState.get_quantity(&"fish_soup"), 2)

func test_project_reward_claim_blocks_item_added_reentrancy() -> void:
	WorldState.set_value(&"town_projects:state", {
		"starter_garden_restoration": {
			"progress": {},
			"completed": true,
			"claimed": false,
			"completed_day": WorldClock.day,
			"claimed_day": 0,
		},
	})
	var money_before := PlayerState.money
	var observed := {"entered": false, "inner_result": true}
	var reenter := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"tomato_seeds" or bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_result"] = TownProjects.claim_reward(&"starter_garden_restoration")
	InventoryState.item_added.connect(reenter)
	assert_true(TownProjects.claim_reward(&"starter_garden_restoration"))
	if InventoryState.item_added.is_connected(reenter):
		InventoryState.item_added.disconnect(reenter)
	assert_true(bool(observed["entered"]))
	assert_false(bool(observed["inner_result"]))
	assert_true(TownProjects.is_claimed(&"starter_garden_restoration"))
	assert_eq(InventoryState.get_quantity(&"tomato_seeds"), 6)
	assert_eq(PlayerState.money, money_before + 600)

func test_completed_project_grants_the_reward_promised_at_completion() -> void:
	WorldState.set_value(&"town_projects:state", {
		"starter_garden_restoration": {
			"progress": {},
			"completed": true,
			"claimed": false,
			"completed_day": WorldClock.day,
			"claimed_day": 0,
			"reward_snapshot": {"items": {"wood": 3, "removed_item": 2}, "money": 999},
		},
	})
	var money_before := PlayerState.money
	assert_true(TownProjects.claim_reward(&"starter_garden_restoration"))
	assert_eq(PlayerState.money, money_before + 999)
	assert_eq(InventoryState.get_quantity(&"wood"), 3)
	assert_eq(InventoryState.get_quantity(&"removed_item"), 0)
	assert_eq(InventoryState.get_quantity(&"tomato_seeds"), 0)

func test_project_contribution_blocks_item_removed_reentrancy() -> void:
	InventoryState.add_item_by_id(&"turnip", 2)
	var observed := {"entered": false, "inner_donated": -1}
	var reenter := func(_item_id: StringName, _quantity: int) -> void:
		if bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_donated"] = TownProjects.contribute(&"starter_garden_restoration", &"turnip", 1)
	InventoryState.item_removed.connect(reenter)
	assert_eq(TownProjects.contribute(&"starter_garden_restoration", &"turnip", 1), 1)
	if InventoryState.item_removed.is_connected(reenter):
		InventoryState.item_removed.disconnect(reenter)
	assert_eq(int(observed["inner_donated"]), 0)
	assert_eq(InventoryState.get_quantity(&"turnip"), 1)
	assert_eq(TownProjects.get_progress(&"starter_garden_restoration", &"turnip"), 1)
	assert_eq(TownProjects.contribute(&"starter_garden_restoration", &"turnip", 1), 1)
	assert_eq(InventoryState.get_quantity(&"turnip"), 0)
	assert_eq(TownProjects.get_progress(&"starter_garden_restoration", &"turnip"), 2)

func test_project_state_sanitizes_malformed_nested_values_and_reward_snapshot() -> void:
	WorldState.set_value(TownProjectService.STATE_KEY, {
		"starter_garden_restoration": {
			"progress": {"turnip": {"bad": true}, "carrot": -3, "potato": 2},
			"completed": {"truthy": true},
			"claimed": false,
			"completed_day": {"bad": true},
			"claimed_day": [9],
			"reward_snapshot": {"items": {"retired": {"quantity": {"bad": true}}}, "money": {"bad": true}},
		},
	})
	assert_eq(TownProjects.get_progress(&"starter_garden_restoration", &"turnip"), 0)
	assert_eq(TownProjects.get_progress(&"starter_garden_restoration", &"carrot"), 0)
	assert_eq(TownProjects.get_progress(&"starter_garden_restoration", &"potato"), 2)
	assert_false(TownProjects.is_completed(&"starter_garden_restoration"))
	var normalized := TownProjects.get_state(&"starter_garden_restoration")
	assert_eq(int(normalized.get("completed_day", -1)), 0)
	assert_eq(int(normalized.get("claimed_day", -1)), 0)

	# A genuinely completed state with corrupted reward metadata remains claimable
	# without crashing; unreadable reward values are safely treated as zero.
	var raw_all := WorldState.get_value(TownProjectService.STATE_KEY, {}) as Dictionary
	var raw_project := (raw_all["starter_garden_restoration"] as Dictionary).duplicate(true)
	raw_project["completed"] = true
	raw_all["starter_garden_restoration"] = raw_project
	WorldState.set_value(TownProjectService.STATE_KEY, raw_all)
	assert_true(TownProjects.claim_reward(&"starter_garden_restoration"))
	assert_true(TownProjects.is_claimed(&"starter_garden_restoration"))
	assert_eq(InventoryState.get_quantity(&"retired"), 0)

func test_town_project_state_round_trips_with_world_state() -> void:
	InventoryState.add_item_by_id(&"turnip", 2)
	assert_eq(TownProjects.contribute(&"starter_garden_restoration", &"turnip", 2), 2)
	var snapshot := WorldState.to_save_data()
	WorldState.clear()
	assert_eq(TownProjects.get_progress(&"starter_garden_restoration", &"turnip"), 0)
	WorldState.load_save_data(snapshot)
	assert_eq(TownProjects.get_progress(&"starter_garden_restoration", &"turnip"), 2)

func test_project_completion_visual_reacts_to_world_flag() -> void:
	var host := ProjectCompletionVisual.new()
	host.completion_flag = &"project:test_visual"
	host.pending_text = "Pending"
	host.completed_text = "Complete"
	var visual := Polygon2D.new()
	visual.name = "Visual"
	host.add_child(visual)
	var label := Label.new()
	label.name = "Label"
	host.add_child(label)
	add_child_autofree(host)
	await get_tree().process_frame
	assert_eq(label.text, "Pending")
	assert_eq(visual.color, host.pending_color)
	WorldState.set_value(&"project:test_visual", true)
	assert_eq(label.text, "Complete")
	assert_eq(visual.color, host.completed_color)

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
