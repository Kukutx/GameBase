extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

var _quest_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _inventory_max_slots: int
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _world_snapshot: Dictionary

func before_each() -> void:
	_quest_snapshot = QuestState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_inventory_max_slots = InventoryState.max_slots
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	ContentFixture.use(self, _content())
	WorldState.clear()
	InventoryState.clear()
	PlayerState.reset_new_game()
	QuestState.reset_new_game()

func after_each() -> void:
	# The game's content is active again before the stores load their state.
	ContentRegistry.active = ContentDB
	WorldState.load_save_data(_world_snapshot)
	QuestState.load_save_data(_quest_snapshot)
	InventoryState.max_slots = _inventory_max_slots
	InventoryState.load_save_data(_inventory_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)

func test_load_normalizes_progress_and_drops_unknown_quests_and_statuses() -> void:
	QuestState.load_save_data({
		"fixture_smelt": {"status": QuestManager.Status.COMPLETED, "progress": 999},
		"fixture_dig": {"status": 999, "progress": 2},
		"removed_quest": {"status": QuestManager.Status.ACTIVE, "progress": 1},
	})
	assert_true(QuestState.is_completed(&"fixture_smelt"))
	assert_eq(int(QuestState.get_state(&"fixture_smelt").get("progress", 0)), QuestData.find(&"fixture_smelt").required_amount)
	assert_false(QuestState.is_active(&"fixture_dig"))
	var saved := QuestState.to_save_data()
	assert_false(saved.has("fixture_dig"))
	assert_false(saved.has("removed_quest"))

func test_new_game_auto_starts_only_data_declared_entry_quests() -> void:
	assert_true(QuestState.is_active(&"fixture_intro"))
	for quest: QuestData in QuestData.find_all():
		if quest.auto_start:
			assert_true(quest.entry_point, "Auto-start quest %s is not an entry point" % quest.id)
			assert_true(QuestState.is_active(quest.id), "Auto-start quest %s did not start" % quest.id)
		else:
			assert_false(QuestState.is_active(quest.id), "Non-auto quest %s started unexpectedly" % quest.id)

func test_talking_collecting_and_harvesting_complete_their_quests_and_start_the_next() -> void:
	var money_before := PlayerState.money
	NpcSocialEvents.npc_talked.emit(&"fixture_npc", true)
	assert_true(QuestState.is_completed(&"fixture_intro"))
	assert_eq(PlayerState.money, money_before + 50)
	assert_true(QuestState.is_active(&"fixture_gather"))
	InventoryState.add_item_by_id(&"fixture_berry", 2)
	assert_false(QuestState.is_completed(&"fixture_gather"))
	InventoryState.add_item_by_id(&"fixture_berry", 1)
	assert_true(QuestState.is_completed(&"fixture_gather"))
	assert_true(QuestState.is_active(&"fixture_harvest"))
	LifesimEvents.crop_harvested.emit(&"fixture_radish_crop", &"fixture_radish", 1)
	assert_true(QuestState.is_completed(&"fixture_harvest"))

func test_only_items_the_player_gains_count_as_collected() -> void:
	NpcSocialEvents.npc_talked.emit(&"fixture_npc", true)
	InventoryState.add_item_by_id(&"fixture_berry", 2)
	# Berries put away and taken back, or refunded, are the same berries.
	assert_true(InventoryState.return_items_atomic({"fixture_berry": 2}))
	assert_eq(int(QuestState.get_state(&"fixture_gather").get("progress", 0)), 2)
	assert_true(InventoryState.apply_transaction_atomic({}, {"fixture_berry": 1}))
	assert_true(QuestState.is_completed(&"fixture_gather"))

func test_item_reward_quest_waits_for_inventory_space_then_completes_atomically() -> void:
	QuestState.load_save_data({})
	InventoryState.clear()
	InventoryState.max_slots = 1
	assert_eq(InventoryState.add_item_by_id(&"fixture_rod", 1), 0)
	assert_true(QuestState.start_quest(&"fixture_slime_quest"))
	var money_before := PlayerState.money

	CombatEvents.enemy_defeated.emit(&"fixture_slime", 20)
	var blocked_state := QuestState.get_state(&"fixture_slime_quest")
	assert_true(QuestState.is_active(&"fixture_slime_quest"))
	assert_eq(int(blocked_state["progress"]), 1)
	assert_true(blocked_state.get("reward_snapshot", {}) is Dictionary)
	assert_false((blocked_state.get("reward_snapshot", {}) as Dictionary).is_empty())
	assert_eq(PlayerState.money, money_before)
	assert_eq(InventoryState.get_quantity(&"fixture_snack"), 0)
	assert_false(QuestState.is_active(&"fixture_smelt"))

	assert_true(InventoryState.remove_item(&"fixture_rod", 1))
	await get_tree().process_frame
	assert_true(QuestState.is_completed(&"fixture_slime_quest"))
	assert_eq(PlayerState.money, money_before + 200)
	assert_eq(InventoryState.get_quantity(&"fixture_snack"), 1)
	assert_true(QuestState.is_active(&"fixture_smelt"))

func test_loaded_quest_waiting_for_inventory_space_completes_with_its_promised_reward() -> void:
	QuestState.load_save_data({
		"fixture_slime_quest": {
			"status": QuestManager.Status.ACTIVE,
			"progress": 1,
			"reward_snapshot": {"items": {"fixture_twig": 5}, "money": 654},
		},
	})
	InventoryState.clear()
	var money_before := PlayerState.money
	QuestState.complete_ready_quests()
	assert_true(QuestState.is_completed(&"fixture_slime_quest"))
	assert_true(QuestState.is_active(&"fixture_smelt"))
	assert_eq(PlayerState.money, money_before + 654)
	assert_eq(InventoryState.get_quantity(&"fixture_twig"), 5)
	assert_eq(InventoryState.get_quantity(&"fixture_snack"), 0)

func test_chain_progresses_through_fishing_mining_combat_processing_upgrades_and_depth() -> void:
	QuestState.load_save_data({})
	assert_true(QuestState.start_quest(&"fixture_catch"))
	LifesimEvents.fish_caught.emit(&"fixture_other_fish", &"fixture_trout")
	assert_false(QuestState.is_completed(&"fixture_catch"), "another fish does not count")
	LifesimEvents.fish_caught.emit(&"fixture_trout_fish", &"fixture_trout")
	assert_true(QuestState.is_completed(&"fixture_catch"))
	assert_true(QuestState.is_active(&"fixture_dig"))
	LifesimEvents.resource_mined.emit(&"fixture_pebble_rock", &"fixture_pebble", 2)
	assert_true(QuestState.is_completed(&"fixture_dig"))
	assert_true(QuestState.is_active(&"fixture_slime_quest"))
	CombatEvents.enemy_defeated.emit(&"fixture_slime", 20)
	assert_true(QuestState.is_completed(&"fixture_slime_quest"))
	assert_true(QuestState.is_active(&"fixture_smelt"))
	LifesimEvents.item_processed.emit(&"fixture_press", &"fixture_oil", 1)
	assert_false(QuestState.is_completed(&"fixture_smelt"))
	LifesimEvents.item_processed.emit(&"fixture_press", &"fixture_oil", 1)
	assert_true(QuestState.is_completed(&"fixture_smelt"))
	assert_true(QuestState.is_active(&"fixture_upgrade"))
	ProgressionEvents.tool_upgraded.emit(&"fixture_rod_upgrade", &"fixture_rod")
	assert_true(QuestState.is_completed(&"fixture_upgrade"))
	assert_true(QuestState.is_active(&"fixture_dive"))
	assert_eq(int(QuestState.get_state(&"fixture_dive")["progress"]), 1, "a depth quest starts at the deepest floor reached")
	MineState.set_floor(5)
	assert_eq(int(QuestState.get_state(&"fixture_dive")["progress"]), 5)
	MineState.set_floor(6)
	assert_true(QuestState.is_completed(&"fixture_dive"))

## Two entry points: an intro that starts with a new game (talk, collect,
## harvest) and an exploration chain started by hand (fish, mine, defeat,
## process, upgrade, reach a mine floor).
func _content() -> Array:
	var intro := _quest(&"fixture_intro", QuestData.ObjectiveType.TALK, &"fixture_npc", 1, &"fixture_gather")
	intro.entry_point = true
	intro.auto_start = true
	intro.reward_money = 50
	var exploration := _quest(&"fixture_catch", QuestData.ObjectiveType.FISH, &"fixture_trout_fish", 1, &"fixture_dig")
	exploration.entry_point = true
	var slime := _quest(&"fixture_slime_quest", QuestData.ObjectiveType.DEFEAT, &"fixture_slime", 1, &"fixture_smelt")
	slime.reward_money = 200
	slime.reward_items = {"fixture_snack": 1}
	var rod := _item(&"fixture_rod")
	rod.kind = ItemData.Kind.TOOL
	rod.max_stack = 1
	rod.tool_action = ItemData.ACTION_FISH
	return [
		intro,
		_quest(&"fixture_gather", QuestData.ObjectiveType.COLLECT, &"fixture_berry", 3, &"fixture_harvest"),
		_quest(&"fixture_harvest", QuestData.ObjectiveType.HARVEST, &"fixture_radish_crop", 1, &""),
		exploration,
		_quest(&"fixture_dig", QuestData.ObjectiveType.MINE, &"fixture_pebble_rock", 2, &"fixture_slime_quest"),
		slime,
		_quest(&"fixture_smelt", QuestData.ObjectiveType.PROCESS, &"fixture_press", 2, &"fixture_upgrade"),
		_quest(&"fixture_upgrade", QuestData.ObjectiveType.UPGRADE, &"fixture_rod_upgrade", 1, &"fixture_dive"),
		_quest(&"fixture_dive", QuestData.ObjectiveType.REACH_MINE_FLOOR, &"", 6, &""),
		rod,
		_item(&"fixture_berry"),
		_item(&"fixture_snack"),
		_item(&"fixture_twig"),
	]

func _quest(id: StringName, objective_type: QuestData.ObjectiveType, target_id: StringName, required_amount: int, next_quest_id: StringName) -> QuestData:
	var quest := QuestData.new()
	quest.id = id
	quest.title = String(id).capitalize()
	quest.objective_type = objective_type
	quest.target_id = target_id
	quest.required_amount = required_amount
	quest.next_quest_id = next_quest_id
	return quest

func _item(id: StringName) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	return item
