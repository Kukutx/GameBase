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
		"fixture_smelt": {"status": QuestManager.Status.COMPLETED, "progress": [0]},
		"fixture_dig": {"status": 999, "progress": [2]},
		"fixture_gather": {"status": QuestManager.Status.ACTIVE, "progress": [999, 7]},
		"fixture_harvest": {"status": QuestManager.Status.ACTIVE, "progress": 1},
		"removed_quest": {"status": QuestManager.Status.ACTIVE, "progress": [1]},
	})
	assert_true(QuestState.is_completed(&"fixture_smelt"))
	assert_eq(QuestState.get_progress(&"fixture_smelt"), 2, "a completed quest met every objective")
	assert_eq(QuestState.get_state(&"fixture_gather")["progress"], [3], "progress stops at what the objective requires, one per objective")
	assert_eq(QuestState.get_state(&"fixture_harvest")["progress"], [0], "progress that is no list counts nothing")
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
	assert_eq(QuestState.get_progress(&"fixture_gather"), 2)
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
	assert_eq(blocked_state["progress"], [1])
	assert_true(blocked_state.get("reward_snapshot", {}) is Dictionary)
	assert_false((blocked_state.get("reward_snapshot", {}) as Dictionary).is_empty())
	assert_eq(PlayerState.money, money_before)
	assert_eq(InventoryState.get_quantity(&"fixture_snack"), 0)
	assert_false(QuestState.is_active(&"fixture_smelt"))
	assert_true(QuestState.start_quest(&"fixture_errands"))
	watch_signals(GameEvents)
	LifesimEvents.crop_harvested.emit(&"fixture_radish_crop", &"fixture_radish", 1)
	assert_signal_not_emitted(GameEvents, "toast_requested", "an event that moves another quest on retries no waiting reward")

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
			"progress": [1],
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
	assert_eq(QuestState.get_progress(&"fixture_dive"), 1, "a measured objective starts at what it measures")
	MineState.set_floor(5)
	assert_eq(QuestState.get_progress(&"fixture_dive"), 5)
	MineState.set_floor(6)
	assert_true(QuestState.is_completed(&"fixture_dive"))

func test_a_quest_of_several_objectives_completes_once_all_are_met() -> void:
	QuestState.load_save_data({})
	assert_true(QuestState.start_quest(&"fixture_errands"))
	watch_signals(QuestState)
	LifesimEvents.crop_harvested.emit(&"fixture_radish_crop", &"fixture_radish", 4)
	assert_eq(QuestState.get_state(&"fixture_errands")["progress"], [2, 0], "the harvest counts up to what it requires")
	assert_signal_emitted_with_parameters(QuestState, "quest_progressed", [&"fixture_errands", 0, 2, 2])
	assert_true(QuestState.is_active(&"fixture_errands"))
	NpcSocialEvents.npc_talked.emit(&"fixture_other_npc", true)
	assert_true(QuestState.is_active(&"fixture_errands"), "a talk with someone else is not the errand")
	NpcSocialEvents.npc_talked.emit(&"fixture_npc", false)
	assert_true(QuestState.is_completed(&"fixture_errands"))
	var journal := QuestState.get_journal_entries()
	assert_eq(journal.size(), 1)
	assert_eq((journal[0]["objectives"] as Array).size(), 2)
	assert_eq(journal[0]["objectives"][1], {"description": "Tell the fixture NPC", "progress": 1, "required": 1})

func test_it_listens_only_to_what_active_quests_count_and_not_while_the_game_changes() -> void:
	QuestState.load_save_data({})
	assert_true(QuestState._listeners.is_empty(), "no active quest listens to nothing")
	assert_true(QuestState.start_quest(&"fixture_catch"))
	assert_eq(QuestState._listeners.keys(), [&"LifesimEvents.fish_caught"])
	GameSaveManager._restoring = true
	LifesimEvents.fish_caught.emit(&"fixture_trout_fish", &"fixture_trout")
	GameSaveManager._restoring = false
	assert_true(QuestState.is_active(&"fixture_catch"), "what a load or a new game announces is not play")
	LifesimEvents.fish_caught.emit(&"fixture_trout_fish", &"fixture_trout")
	assert_true(QuestState.is_completed(&"fixture_catch"))
	assert_false(QuestState._listeners.has(&"LifesimEvents.fish_caught"), "a completed quest stops listening")

## Two entry points: an intro that starts with a new game (talk, collect,
## harvest) and an exploration chain started by hand (fish, mine, defeat,
## process, upgrade, reach a mine floor); and a quest of two objectives.
func _content() -> Array:
	var intro := _quest(&"fixture_intro", [_objective(&"NpcSocialEvents.npc_talked", "EVENT_ARG npc_id fixture_npc")], &"fixture_gather")
	intro.entry_point = true
	intro.auto_start = true
	intro.reward_money = 50
	var exploration := _quest(&"fixture_catch", [_objective(&"LifesimEvents.fish_caught", "EVENT_ARG fish_id fixture_trout_fish")], &"fixture_dig")
	exploration.entry_point = true
	var slime := _quest(&"fixture_slime_quest", [_objective(&"CombatEvents.enemy_defeated", "EVENT_ARG enemy_id fixture_slime")], &"fixture_smelt")
	slime.reward_money = 200
	slime.reward_items = {"fixture_snack": 1}
	var dive := _objective(&"MineState.deepest_floor_changed", "", &"", 6)
	dive.measure = &"MineState.get_deepest_floor"
	var tell := _objective(&"NpcSocialEvents.npc_talked", "EVENT_ARG npc_id fixture_npc")
	tell.description = "Tell the fixture NPC"
	var harvest := _objective(&"LifesimEvents.crop_harvested", "", &"quantity", 2)
	harvest.description = "Harvest two crops"
	var errands := _quest(&"fixture_errands", [harvest, tell], &"")
	errands.entry_point = true
	var rod := _item(&"fixture_rod")
	rod.kind = ItemData.Kind.TOOL
	rod.max_stack = 1
	rod.tool_action = FishingSpot.TOOL_ACTION
	return [
		intro,
		_quest(&"fixture_gather", [_objective(&"InventoryState.item_gained", "EVENT_ARG item_id fixture_berry", &"quantity", 3)], &"fixture_harvest"),
		_quest(&"fixture_harvest", [_objective(&"LifesimEvents.crop_harvested", "EVENT_ARG crop_id fixture_radish_crop", &"quantity")], &""),
		exploration,
		_quest(&"fixture_dig", [_objective(&"LifesimEvents.resource_mined", "EVENT_ARG mining_node_id fixture_pebble_rock", &"quantity", 2)], &"fixture_slime_quest"),
		slime,
		_quest(&"fixture_smelt", [_objective(&"LifesimEvents.item_processed", "EVENT_ARG processing_recipe_id fixture_press", &"quantity", 2)], &"fixture_upgrade"),
		_quest(&"fixture_upgrade", [_objective(&"ProgressionEvents.tool_upgraded", "EVENT_ARG tool_upgrade_id fixture_rod_upgrade")], &"fixture_dive"),
		_quest(&"fixture_dive", [dive], &""),
		errands,
		rod,
		_item(&"fixture_berry"),
		_item(&"fixture_snack"),
		_item(&"fixture_twig"),
	]

func _quest(id: StringName, objectives: Array[QuestObjective], next_quest_id: StringName) -> QuestData:
	var quest := QuestData.new()
	quest.id = id
	quest.title = String(id).capitalize()
	quest.objectives = objectives
	quest.next_quest_id = next_quest_id
	return quest

func _objective(event: StringName, condition: String, count_per := &"", required_amount := 1) -> QuestObjective:
	var objective := QuestObjective.new()
	objective.event = event
	objective.condition = condition
	objective.count_per = count_per
	objective.required_amount = required_amount
	return objective

func _item(id: StringName) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	return item
