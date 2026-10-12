extends GutTest

## Farm1's quest chain and its rewards. How quests start, progress, save and
## pay out is tested with the progression module.

var _quest_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _vitals_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _world_snapshot: Dictionary
var _skills_snapshot: Dictionary

func before_each() -> void:
	_quest_snapshot = QuestState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = Wallet.to_save_data()
	_vitals_snapshot = Vitals.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	_skills_snapshot = Skills.to_save_data()
	WorldState.clear()
	InventoryState.clear()
	Wallet.reset_new_game()
	Vitals.reset_new_game()
	QuestState.reset_new_game()

func after_each() -> void:
	WorldState.load_save_data(_world_snapshot)
	QuestState.load_save_data(_quest_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	Wallet.load_save_data(_player_snapshot)
	Vitals.load_save_data(_vitals_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	Skills.load_save_data(_skills_snapshot)

func test_talking_to_mira_completes_intro_quest() -> void:
	NpcSocialEvents.npc_talked.emit(&"mira", true)
	assert_true(QuestState.is_completed(&"meet_mira"))
	assert_eq(Wallet.money, 550)

func test_defeating_a_green_slime_rewards_two_hundred_gold_and_a_field_snack() -> void:
	QuestState.load_save_data({})
	assert_true(QuestState.start_quest(&"defeat_green_slime"))
	var money_before := Wallet.money
	CombatEvents.enemy_defeated.emit(&"green_slime", 20, Vector2.ZERO)
	assert_true(QuestState.is_completed(&"defeat_green_slime"))
	assert_eq(Wallet.money, money_before + 200)
	assert_eq(InventoryState.get_quantity(&"field_snack"), 1)

func test_collecting_berries_unlocks_first_harvest() -> void:
	InventoryState.add_item_by_id(&"berry", 3)
	assert_true(QuestState.is_completed(&"gather_berries"))
	assert_true(QuestState.is_active(&"first_harvest"))

func test_exploration_chain_progresses_from_fishing_to_mining_to_combat() -> void:
	QuestState.load_save_data({})
	assert_true(QuestState.start_quest(&"catch_first_fish"))
	LifesimEvents.fish_caught.emit(&"river_carp", &"river_carp")
	assert_true(QuestState.is_completed(&"catch_first_fish"))
	assert_true(QuestState.is_active(&"mine_stone"))
	LifesimEvents.resource_mined.emit(&"stone_rock", &"stone", 2, Vector2.ZERO)
	assert_true(QuestState.is_completed(&"mine_stone"))
	assert_true(QuestState.is_active(&"defeat_green_slime"))
	CombatEvents.enemy_defeated.emit(&"green_slime", 20, Vector2.ZERO)
	assert_true(QuestState.is_completed(&"defeat_green_slime"))
	assert_true(QuestState.is_active(&"smelt_copper"))
	LifesimEvents.item_processed.emit(&"smelt_copper_bar", &"copper_bar", 1, Vector2.ZERO)
	assert_false(QuestState.is_completed(&"smelt_copper"))
	LifesimEvents.item_processed.emit(&"smelt_copper_bar", &"copper_bar", 1, Vector2.ZERO)
	assert_true(QuestState.is_completed(&"smelt_copper"))
	assert_true(QuestState.is_active(&"upgrade_pickaxe"))
	ProgressionEvents.tool_upgraded.emit(&"copper_pickaxe_upgrade", &"copper_pickaxe")
	assert_true(QuestState.is_completed(&"upgrade_pickaxe"))
	assert_true(QuestState.is_active(&"reach_iron_depth"))

func test_iron_depth_chain_syncs_from_mine_progress_and_closes_at_smelting() -> void:
	QuestState.load_save_data({})
	MineState.enter_from_surface()
	assert_true(QuestState.start_quest(&"reach_iron_depth"))
	assert_eq(QuestState.get_progress(&"reach_iron_depth"), 1)
	MineState.set_floor(6)
	assert_true(QuestState.is_completed(&"reach_iron_depth"))
	assert_true(QuestState.is_active(&"mine_iron"))
	LifesimEvents.resource_mined.emit(&"iron_rock", &"iron_ore", 2, Vector2.ZERO)
	assert_true(QuestState.is_completed(&"mine_iron"))
	assert_true(QuestState.is_active(&"smelt_iron"))
	LifesimEvents.item_processed.emit(&"smelt_iron_bar", &"iron_bar", 1, Vector2.ZERO)
	assert_false(QuestState.is_completed(&"smelt_iron"))
	LifesimEvents.item_processed.emit(&"smelt_iron_bar", &"iron_bar", 1, Vector2.ZERO)
	assert_true(QuestState.is_completed(&"smelt_iron"))
	assert_true(QuestState.is_active(&"reach_gold_depth"))

func test_late_mine_quest_chain_runs_from_gold_to_iridium_and_floor_one_twenty() -> void:
	QuestState.load_save_data({})
	MineState.enter_from_surface()
	assert_true(QuestState.start_quest(&"smelt_iron"))
	LifesimEvents.item_processed.emit(&"smelt_iron_bar", &"iron_bar", 2, Vector2.ZERO)
	assert_true(QuestState.is_completed(&"smelt_iron"))
	assert_true(QuestState.is_active(&"reach_gold_depth"))

	MineState.set_floor(20)
	assert_true(QuestState.is_completed(&"reach_gold_depth"))
	assert_true(QuestState.is_active(&"mine_gold"))
	LifesimEvents.resource_mined.emit(&"gold_rock", &"gold_ore", 2, Vector2.ZERO)
	assert_true(QuestState.is_completed(&"mine_gold"))
	assert_true(QuestState.is_active(&"smelt_gold"))
	LifesimEvents.item_processed.emit(&"smelt_gold_bar", &"gold_bar", 2, Vector2.ZERO)
	assert_true(QuestState.is_completed(&"smelt_gold"))
	assert_true(QuestState.is_active(&"reach_iridium_depth"))

	MineState.set_floor(60)
	assert_true(QuestState.is_completed(&"reach_iridium_depth"))
	assert_true(QuestState.is_active(&"mine_iridium"))
	LifesimEvents.resource_mined.emit(&"iridium_rock", &"iridium_ore", 2, Vector2.ZERO)
	assert_true(QuestState.is_completed(&"mine_iridium"))
	assert_true(QuestState.is_active(&"smelt_iridium"))
	LifesimEvents.item_processed.emit(&"smelt_iridium_bar", &"iridium_bar", 2, Vector2.ZERO)
	assert_true(QuestState.is_completed(&"smelt_iridium"))
	assert_true(QuestState.is_active(&"reach_mine_bottom"))

	var money_before_bottom := Wallet.money
	var bars_before_bottom := InventoryState.get_quantity(&"iridium_bar")
	MineState.set_floor(120)
	assert_true(QuestState.is_completed(&"reach_mine_bottom"))
	assert_eq(Wallet.money, money_before_bottom + 5000)
	assert_eq(InventoryState.get_quantity(&"iridium_bar"), bars_before_bottom + 2)
