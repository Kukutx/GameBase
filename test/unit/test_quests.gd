extends GutTest

var _quest_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _inventory_max_slots: int
var _player_snapshot: Dictionary
var _world_snapshot: Dictionary

func before_each() -> void:
	_quest_snapshot = QuestState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_inventory_max_slots = InventoryState.max_slots
	_player_snapshot = PlayerState.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	WorldState.clear()
	InventoryState.clear()
	PlayerState.reset_new_game()
	QuestState.reset_new_game()

func after_each() -> void:
	WorldState.load_save_data(_world_snapshot)
	QuestState.load_save_data(_quest_snapshot)
	InventoryState.max_slots = _inventory_max_slots
	InventoryState.load_save_data(_inventory_snapshot)
	PlayerState.load_save_data(_player_snapshot)

func test_loaded_completed_quest_repairs_appended_chain_and_syncs_historical_depth() -> void:
	MineState.set_floor(25)
	QuestState.load_save_data({
		"smelt_iron": {"status": QuestManager.Status.COMPLETED, "progress": 999},
		"retired_quest": {"status": 77, "progress": 12, "legacy_note": "preserve"},
	})
	assert_true(QuestState.is_completed(&"smelt_iron"))
	assert_eq(int(QuestState.get_state(&"smelt_iron").get("progress", 0)), ContentDB.get_quest(&"smelt_iron").required_amount)
	assert_true(QuestState.is_active(&"reach_gold_depth"))
	assert_false(QuestState.is_active(&"mine_gold"))
	assert_true(QuestState.to_save_data().has("retired_quest"))

	var money_before := PlayerState.money
	QuestState.reconcile_loaded_progress()
	assert_true(QuestState.is_completed(&"reach_gold_depth"))
	assert_true(QuestState.is_active(&"mine_gold"))
	assert_eq(PlayerState.money, money_before + ContentDB.get_quest(&"reach_gold_depth").reward_money)

func test_invalid_known_quest_status_is_normalized_without_deleting_unknown_history() -> void:
	QuestState.load_save_data({
		"mine_gold": {"status": 999, "progress": 2},
		"retired_quest": {"status": 999, "progress": 9, "legacy": true},
	})
	assert_true(QuestState.is_active(&"mine_gold"))
	assert_eq(int(QuestState.get_state(&"mine_gold").get("progress", 0)), 2)
	var saved := QuestState.to_save_data()
	assert_true(saved.has("retired_quest"))
	assert_eq(int((saved["retired_quest"] as Dictionary).get("status", 0)), 999)
	assert_true(bool((saved["retired_quest"] as Dictionary).get("legacy", false)))

func test_new_game_auto_starts_only_data_declared_entry_quests() -> void:
	for quest: QuestData in ContentDB.get_all_quests():
		if quest.auto_start:
			assert_true(quest.entry_point, "Auto-start quest %s is not an entry point" % quest.id)
			assert_true(QuestState.is_active(quest.id), "Auto-start quest %s did not start" % quest.id)
		else:
			assert_false(QuestState.is_active(quest.id), "Non-auto quest %s started unexpectedly" % quest.id)

func test_talking_to_mira_completes_intro_quest() -> void:
	QuestState.notify_npc_talk(&"mira")
	assert_true(QuestState.is_completed(&"meet_mira"))
	assert_eq(PlayerState.money, 550)

func test_collecting_berries_unlocks_first_harvest() -> void:
	InventoryState.add_item_by_id(&"berry", 3)
	assert_true(QuestState.is_completed(&"gather_berries"))
	assert_true(QuestState.is_active(&"first_harvest"))

func test_item_reward_quest_waits_for_inventory_space_then_completes_atomically() -> void:
	QuestState.load_save_data({})
	InventoryState.clear()
	InventoryState.max_slots = 1
	assert_eq(InventoryState.add_item_by_id(&"fishing_rod", 1), 0)
	assert_true(QuestState.start_quest(&"defeat_green_slime"))
	var money_before := PlayerState.money

	GameEvents.enemy_defeated.emit(&"green_slime", 20)
	var blocked_state := QuestState.get_state(&"defeat_green_slime")
	assert_true(QuestState.is_active(&"defeat_green_slime"))
	assert_eq(int(blocked_state["progress"]), 1)
	assert_true(blocked_state.get("reward_snapshot", {}) is Dictionary)
	assert_false((blocked_state.get("reward_snapshot", {}) as Dictionary).is_empty())
	assert_eq(PlayerState.money, money_before)
	assert_eq(InventoryState.get_quantity(&"field_snack"), 0)
	assert_false(QuestState.is_active(&"smelt_copper"))

	assert_true(InventoryState.remove_item(&"fishing_rod", 1))
	await get_tree().process_frame
	assert_true(QuestState.is_completed(&"defeat_green_slime"))
	assert_eq(PlayerState.money, money_before + 200)
	assert_eq(InventoryState.get_quantity(&"field_snack"), 1)
	assert_true(QuestState.is_active(&"smelt_copper"))

func test_blocked_quest_keeps_promised_reward_snapshot_across_content_removal() -> void:
	QuestState.load_save_data({
		"defeat_green_slime": {
			"status": QuestManager.Status.ACTIVE,
			"progress": 1,
			"reward_snapshot": {
				"items": {
					"retired_quest_token": {"quantity": 5, "display_name": "Retired Quest Token", "max_stack": 10},
				},
				"money": 654,
			},
		},
	})
	InventoryState.clear()
	var money_before := PlayerState.money
	QuestState.reconcile_loaded_progress()
	assert_true(QuestState.is_completed(&"defeat_green_slime"))
	assert_true(QuestState.is_active(&"smelt_copper"))
	assert_eq(PlayerState.money, money_before + 654)
	assert_eq(InventoryState.get_quantity(&"retired_quest_token"), 5)
	assert_eq(InventoryState.get_quantity(&"field_snack"), 0)
	assert_eq(InventoryState.get_used_slots(), 0)

func test_exploration_chain_progresses_from_fishing_to_mining_to_combat() -> void:
	QuestState.load_save_data({})
	assert_true(QuestState.start_quest(&"catch_first_fish"))
	GameEvents.fish_caught.emit(&"river_carp", &"river_carp")
	assert_true(QuestState.is_completed(&"catch_first_fish"))
	assert_true(QuestState.is_active(&"mine_stone"))
	GameEvents.resource_mined.emit(&"stone_rock", &"stone", 2)
	assert_true(QuestState.is_completed(&"mine_stone"))
	assert_true(QuestState.is_active(&"defeat_green_slime"))
	GameEvents.enemy_defeated.emit(&"green_slime", 20)
	assert_true(QuestState.is_completed(&"defeat_green_slime"))
	assert_true(QuestState.is_active(&"smelt_copper"))
	GameEvents.item_processed.emit(&"smelt_copper_bar", &"copper_bar", 1)
	assert_false(QuestState.is_completed(&"smelt_copper"))
	GameEvents.item_processed.emit(&"smelt_copper_bar", &"copper_bar", 1)
	assert_true(QuestState.is_completed(&"smelt_copper"))
	assert_true(QuestState.is_active(&"upgrade_pickaxe"))
	GameEvents.tool_upgraded.emit(&"copper_pickaxe_upgrade", &"copper_pickaxe")
	assert_true(QuestState.is_completed(&"upgrade_pickaxe"))
	assert_true(QuestState.is_active(&"reach_iron_depth"))

func test_iron_depth_chain_syncs_from_mine_progress_and_closes_at_smelting() -> void:
	QuestState.load_save_data({})
	MineState.enter_from_surface()
	assert_true(QuestState.start_quest(&"reach_iron_depth"))
	assert_eq(int(QuestState.get_state(&"reach_iron_depth")["progress"]), 1)
	MineState.set_floor(6)
	assert_true(QuestState.is_completed(&"reach_iron_depth"))
	assert_true(QuestState.is_active(&"mine_iron"))
	GameEvents.resource_mined.emit(&"iron_rock", &"iron_ore", 2)
	assert_true(QuestState.is_completed(&"mine_iron"))
	assert_true(QuestState.is_active(&"smelt_iron"))
	GameEvents.item_processed.emit(&"smelt_iron_bar", &"iron_bar", 1)
	assert_false(QuestState.is_completed(&"smelt_iron"))
	GameEvents.item_processed.emit(&"smelt_iron_bar", &"iron_bar", 1)
	assert_true(QuestState.is_completed(&"smelt_iron"))
	assert_true(QuestState.is_active(&"reach_gold_depth"))

func test_late_mine_quest_chain_runs_from_gold_to_iridium_and_floor_one_twenty() -> void:
	QuestState.load_save_data({})
	MineState.enter_from_surface()
	assert_true(QuestState.start_quest(&"smelt_iron"))
	GameEvents.item_processed.emit(&"smelt_iron_bar", &"iron_bar", 2)
	assert_true(QuestState.is_completed(&"smelt_iron"))
	assert_true(QuestState.is_active(&"reach_gold_depth"))

	MineState.set_floor(20)
	assert_true(QuestState.is_completed(&"reach_gold_depth"))
	assert_true(QuestState.is_active(&"mine_gold"))
	GameEvents.resource_mined.emit(&"gold_rock", &"gold_ore", 2)
	assert_true(QuestState.is_completed(&"mine_gold"))
	assert_true(QuestState.is_active(&"smelt_gold"))
	GameEvents.item_processed.emit(&"smelt_gold_bar", &"gold_bar", 2)
	assert_true(QuestState.is_completed(&"smelt_gold"))
	assert_true(QuestState.is_active(&"reach_iridium_depth"))

	MineState.set_floor(60)
	assert_true(QuestState.is_completed(&"reach_iridium_depth"))
	assert_true(QuestState.is_active(&"mine_iridium"))
	GameEvents.resource_mined.emit(&"iridium_rock", &"iridium_ore", 2)
	assert_true(QuestState.is_completed(&"mine_iridium"))
	assert_true(QuestState.is_active(&"smelt_iridium"))
	GameEvents.item_processed.emit(&"smelt_iridium_bar", &"iridium_bar", 2)
	assert_true(QuestState.is_completed(&"smelt_iridium"))
	assert_true(QuestState.is_active(&"reach_mine_bottom"))

	var money_before_bottom := PlayerState.money
	var bars_before_bottom := InventoryState.get_quantity(&"iridium_bar")
	MineState.set_floor(120)
	assert_true(QuestState.is_completed(&"reach_mine_bottom"))
	assert_eq(PlayerState.money, money_before_bottom + 5000)
	assert_eq(InventoryState.get_quantity(&"iridium_bar"), bars_before_bottom + 2)
