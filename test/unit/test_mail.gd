extends GutTest

var _world_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _quest_snapshot: Dictionary
var _relationship_snapshot: Dictionary
var _clock_snapshot: Dictionary

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_quest_snapshot = QuestState.to_save_data()
	_relationship_snapshot = RelationshipState.to_save_data()
	_clock_snapshot = WorldClock.to_save_data()
	WorldState.clear()
	InventoryState.clear()
	PlayerState.reset_new_game()
	QuestState.load_save_data({})
	RelationshipState.clear()
	WorldClock.set_time(1, 8 * 60)

func after_each() -> void:
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	QuestState.load_save_data(_quest_snapshot)
	RelationshipState.load_save_data(_relationship_snapshot)
	WorldClock.load_save_data(_clock_snapshot)

func test_welcome_mail_delivers_on_day_two_and_rewards_once() -> void:
	assert_false(MailState.is_received(&"mira_welcome"))
	assert_true(MailState.refresh_deliveries().is_empty())
	WorldClock.set_time(2, 8 * 60)
	MailState.refresh_deliveries()
	assert_true(MailState.is_received(&"mira_welcome"))
	assert_false(MailState.is_read(&"mira_welcome"))
	assert_eq(MailState.get_unread_mail().size(), 1)
	var seeds_before := InventoryState.get_quantity(&"turnip_seeds")
	assert_true(MailState.claim_rewards(&"mira_welcome"))
	assert_true(MailState.is_read(&"mira_welcome"))
	assert_true(MailState.is_claimed(&"mira_welcome"))
	assert_eq(InventoryState.get_quantity(&"turnip_seeds"), seeds_before + 3)
	assert_false(MailState.claim_rewards(&"mira_welcome"))
	assert_eq(InventoryState.get_quantity(&"turnip_seeds"), seeds_before + 3)

func test_mail_claim_blocks_item_added_reentrancy() -> void:
	WorldClock.set_time(2, 8 * 60)
	MailState.refresh_deliveries()
	assert_true(MailState.is_received(&"mira_welcome"))
	var seeds_before := InventoryState.get_quantity(&"turnip_seeds")
	var observed := {"entered": false, "inner_result": true}
	var listener := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"turnip_seeds" or bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_result"] = MailState.claim_rewards(&"mira_welcome")
	InventoryState.item_added.connect(listener)
	assert_true(MailState.claim_rewards(&"mira_welcome"))
	if InventoryState.item_added.is_connected(listener):
		InventoryState.item_added.disconnect(listener)
	assert_true(bool(observed["entered"]))
	assert_false(bool(observed["inner_result"]))
	assert_true(MailState.is_claimed(&"mira_welcome"))
	assert_eq(InventoryState.get_quantity(&"turnip_seeds"), seeds_before + 3)

func test_received_mail_uses_promised_reward_snapshot_after_content_removal() -> void:
	WorldState.set_value(&"mail:mira_welcome:received", true)
	WorldState.set_value(&"mail:mira_welcome:reward_snapshot", {
		"items": {
			"retired_mail_token": {"quantity": 4, "display_name": "Retired Mail Token", "max_stack": 12},
		},
		"money": 777,
	})
	var money_before := PlayerState.money
	assert_true(MailState.claim_rewards(&"mira_welcome"))
	assert_true(MailState.is_claimed(&"mira_welcome"))
	assert_true(MailState.is_read(&"mira_welcome"))
	assert_eq(PlayerState.money, money_before + 777)
	assert_eq(InventoryState.get_quantity(&"retired_mail_token"), 4)
	assert_eq(InventoryState.get_quantity(&"turnip_seeds"), 0)
	assert_eq(InventoryState.get_used_slots(), 0)
	var saved_inventory := InventoryState.to_save_data()
	assert_eq(String((saved_inventory["retired_mail_token"] as Dictionary).get("display_name", "")), "Retired Mail Token")

func test_quest_mail_unlocks_from_completed_quest_conditions() -> void:
	assert_false(MailState.is_received(&"rowan_after_slime"))
	assert_false(MailState.is_received(&"neri_first_catch"))
	QuestState.load_save_data({
		"defeat_green_slime": {"status": QuestManager.Status.COMPLETED, "progress": 1},
		"catch_first_fish": {"status": QuestManager.Status.COMPLETED, "progress": 1},
	})
	var delivered := MailState.refresh_deliveries()
	assert_true(delivered.has(&"rowan_after_slime"))
	assert_true(delivered.has(&"neri_first_catch"))
	assert_true(MailState.is_received(&"rowan_after_slime"))
	assert_true(MailState.is_received(&"neri_first_catch"))

func test_mail_flags_round_trip_through_world_state() -> void:
	WorldClock.set_time(2, 8 * 60)
	MailState.refresh_deliveries()
	assert_true(MailState.mark_read(&"mira_welcome"))
	assert_true(MailState.claim_rewards(&"mira_welcome"))
	var saved := WorldState.to_save_data()
	WorldState.clear()
	assert_false(MailState.is_received(&"mira_welcome"))
	WorldState.load_save_data(saved)
	assert_true(MailState.is_received(&"mira_welcome"))
	assert_true(MailState.is_read(&"mira_welcome"))
	assert_true(MailState.is_claimed(&"mira_welcome"))

func test_world_flag_mail_delivers_immediately_without_waiting_for_next_day() -> void:
	assert_false(MailState.is_received(&"mira_garden_restored"))
	WorldState.set_value(&"project:starter_garden:complete", true)
	assert_true(MailState.is_received(&"mira_garden_restored"))
	assert_true(MailState.get_unread_mail().any(func(mail: MailData) -> bool: return mail.id == &"mira_garden_restored"))

func test_mine_bottom_mail_delivers_from_live_quest_completion() -> void:
	assert_false(MailState.is_received(&"rowan_mine_bottom"))
	assert_true(QuestState.start_quest(&"reach_mine_bottom"))
	MineState.set_floor(120)
	assert_true(QuestState.is_completed(&"reach_mine_bottom"))
	assert_true(MailState.is_received(&"rowan_mine_bottom"))

func test_loading_older_progress_immediately_backfills_new_world_flag_mail() -> void:
	var snapshot := {
		"weather": WeatherState.to_save_data(),
		"shipping": ShippingState.to_save_data(),
		"clock": WorldClock.to_save_data(),
		"buffs": BuffState.to_save_data(),
		"inventory": InventoryState.to_save_data(),
		"player_state": PlayerState.to_save_data(),
		"world": {"project:starter_garden:complete": true},
		"relationships": RelationshipState.to_save_data(),
		"npc_memory": NpcMemory.to_save_data(),
		"quests": QuestState.to_save_data(),
		"skills": Skills.to_save_data(),
		"fishing": FishingState.to_save_data(),
		"scene": "",
	}
	assert_false(MailState.is_received(&"mira_garden_restored"))
	assert_true(await SaveManager.apply_snapshot(snapshot))
	assert_true(WorldState.get_bool(&"project:starter_garden:complete"))
	assert_true(MailState.is_received(&"mira_garden_restored"))

func test_content_manifest_contains_progression_mail_entries() -> void:
	var ids: Array[String] = []
	for mail: MailData in ContentDB.get_all_mail():
		ids.append(String(mail.id))
	ids.sort()
	assert_eq(ids, [
		"mira_garden_restored",
		"mira_welcome",
		"neri_first_catch",
		"neri_harbor_restocked",
		"rowan_after_slime",
		"rowan_mine_bottom",
		"rowan_workshop_expanded",
	])
