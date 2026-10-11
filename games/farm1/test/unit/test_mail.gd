extends GutTest

## Farm1's letters: when each arrives and what it brings. How mail is delivered
## and claimed is tested with the progression module.

var _world_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _quest_snapshot: Dictionary
var _relationship_snapshot: Dictionary
var _clock_snapshot: Dictionary

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
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
	Hotbar.load_save_data(_hotbar_snapshot)
	QuestState.load_save_data(_quest_snapshot)
	RelationshipState.load_save_data(_relationship_snapshot)
	WorldClock.load_save_data(_clock_snapshot)

func test_content_contains_progression_mail_entries() -> void:
	var ids: Array[String] = []
	for mail: MailData in MailData.find_all():
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

func test_mira_welcome_arrives_on_day_two_with_three_turnip_seeds() -> void:
	MailState.refresh_deliveries()
	assert_false(MailState.is_received(&"mira_welcome"), "Mira's welcome waits for day 2")
	WorldClock.set_time(2, 8 * 60)
	MailState.refresh_deliveries()
	assert_true(MailState.is_received(&"mira_welcome"))
	assert_true(MailState.claim_rewards(&"mira_welcome"))
	assert_eq(InventoryState.get_quantity(&"turnip_seeds"), 3)

func test_rowan_and_neri_write_after_the_slime_and_first_fish_quests() -> void:
	QuestState.load_save_data({
		"defeat_green_slime": {"status": QuestManager.Status.COMPLETED, "progress": 1},
	})
	MailState.refresh_deliveries()
	assert_true(MailState.is_received(&"rowan_after_slime"))
	assert_false(MailState.is_received(&"neri_first_catch"))

	QuestState.load_save_data({
		"defeat_green_slime": {"status": QuestManager.Status.COMPLETED, "progress": 1},
		"catch_first_fish": {"status": QuestManager.Status.COMPLETED, "progress": 1},
	})
	MailState.refresh_deliveries()
	assert_true(MailState.is_received(&"neri_first_catch"))

func test_mira_garden_restored_arrives_when_the_starter_garden_project_completes() -> void:
	assert_false(MailState.is_received(&"mira_garden_restored"))
	WorldState.set_value(TownProjectService.STATE_KEY, {"starter_garden_restoration": {"completed": true}})
	assert_true(MailState.is_received(&"mira_garden_restored"))

func test_reaching_the_mine_bottom_delivers_rowan_mine_bottom() -> void:
	assert_false(MailState.is_received(&"rowan_mine_bottom"))
	assert_true(QuestState.start_quest(&"reach_mine_bottom"))
	MineState.set_floor(120)
	assert_true(QuestState.is_completed(&"reach_mine_bottom"))
	assert_true(MailState.is_received(&"rowan_mine_bottom"))
