extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

const WELCOME := &"fixture_welcome"
const GARDEN_FLAG := &"fixture_garden_restored"

var _world_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _vitals_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _quest_snapshot: Dictionary
var _relationship_snapshot: Dictionary
var _clock_snapshot: Dictionary

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = Wallet.to_save_data()
	_vitals_snapshot = Vitals.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_quest_snapshot = QuestState.to_save_data()
	_relationship_snapshot = RelationshipState.to_save_data()
	_clock_snapshot = WorldClock.to_save_data()
	ContentFixture.use(self, _content())
	WorldState.clear()
	InventoryState.clear()
	Wallet.reset_new_game()
	Vitals.reset_new_game()
	QuestState.load_save_data({})
	RelationshipState.clear()
	WorldClock.set_time(1, 8 * 60)

func after_each() -> void:
	# The game's content is active again before the stores load their state.
	ContentRegistry.active = ContentDB
	GameSession.set("_starting_new_game", false)
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	Wallet.load_save_data(_player_snapshot)
	Vitals.load_save_data(_vitals_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	QuestState.load_save_data(_quest_snapshot)
	RelationshipState.load_save_data(_relationship_snapshot)
	WorldClock.load_save_data(_clock_snapshot)

func test_dated_mail_delivers_on_its_day_and_rewards_once() -> void:
	assert_false(MailState.is_received(WELCOME))
	assert_true(MailState.refresh_deliveries().is_empty())
	WorldClock.set_time(2, 8 * 60)
	MailState.refresh_deliveries()
	assert_true(MailState.is_received(WELCOME))
	assert_false(MailState.is_read(WELCOME))
	assert_eq(MailState.get_unread_mail().size(), 1)
	var seeds_before := InventoryState.get_quantity(&"fixture_seeds")
	assert_true(MailState.claim_rewards(WELCOME))
	assert_true(MailState.is_read(WELCOME))
	assert_true(MailState.is_claimed(WELCOME))
	assert_eq(InventoryState.get_quantity(&"fixture_seeds"), seeds_before + 3)
	assert_false(MailState.claim_rewards(WELCOME))
	assert_eq(InventoryState.get_quantity(&"fixture_seeds"), seeds_before + 3)

func test_letters_wait_while_the_session_changes_and_arrive_when_play_starts() -> void:
	# A save restoring or a new game being set up: the world is half replaced,
	# so what it announces (a friendship, a day) delivers nothing yet.
	GameSession.set("_starting_new_game", true)
	WorldClock.set_time(2, 8 * 60)
	assert_true(MailState.refresh_deliveries().is_empty())
	assert_false(MailState.is_received(WELCOME))
	GameSession.set("_starting_new_game", false)
	GameSession.play_started.emit()
	assert_true(MailState.is_received(WELCOME))

func test_a_change_that_never_reaches_play_does_not_hold_back_later_letters() -> void:
	# A new game whose start location fails: its steps wrote to the world, and
	# play never starts.
	GameSession.set("_starting_new_game", true)
	WorldState.set_value(&"fixture_unrelated", 1)
	await get_tree().process_frame
	GameSession.set("_starting_new_game", false)
	WorldState.set_value(GARDEN_FLAG, true)
	await get_tree().process_frame
	assert_true(WorldState.get_bool(&"mail:fixture_garden_restored:received"), "the next write is checked")

func test_mail_claim_blocks_item_added_reentrancy() -> void:
	WorldClock.set_time(2, 8 * 60)
	MailState.refresh_deliveries()
	assert_true(MailState.is_received(WELCOME))
	var seeds_before := InventoryState.get_quantity(&"fixture_seeds")
	var observed := {"entered": false, "inner_result": true}
	var listener := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"fixture_seeds" or bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_result"] = MailState.claim_rewards(WELCOME)
	InventoryState.item_added.connect(listener)
	assert_true(MailState.claim_rewards(WELCOME))
	if InventoryState.item_added.is_connected(listener):
		InventoryState.item_added.disconnect(listener)
	assert_true(bool(observed["entered"]))
	assert_false(bool(observed["inner_result"]))
	assert_true(MailState.is_claimed(WELCOME))
	assert_eq(InventoryState.get_quantity(&"fixture_seeds"), seeds_before + 3)

func test_received_mail_grants_the_reward_promised_at_delivery() -> void:
	WorldState.set_value(&"mail:fixture_welcome:received", true)
	WorldState.set_value(&"mail:fixture_welcome:reward_snapshot", {
		"items": {"fixture_twig": 4, "removed_item": 1},
		"money": 777,
	})
	var money_before := Wallet.money
	assert_true(MailState.claim_rewards(WELCOME))
	assert_true(MailState.is_claimed(WELCOME))
	assert_true(MailState.is_read(WELCOME))
	assert_eq(Wallet.money, money_before + 777)
	assert_eq(InventoryState.get_quantity(&"fixture_twig"), 4)
	assert_eq(InventoryState.get_quantity(&"removed_item"), 0)
	assert_eq(InventoryState.get_quantity(&"fixture_seeds"), 0)

func test_quest_mail_unlocks_from_completed_quest_conditions() -> void:
	assert_false(MailState.is_received(&"fixture_after_talk"))
	assert_false(MailState.is_received(&"fixture_after_gift"))
	QuestState.load_save_data({
		"fixture_talk_quest": {"status": QuestManager.Status.COMPLETED, "progress": [1]},
		"fixture_gift_quest": {"status": QuestManager.Status.COMPLETED, "progress": [1]},
	})
	var delivered := MailState.refresh_deliveries()
	assert_true(delivered.has(&"fixture_after_talk"))
	assert_true(delivered.has(&"fixture_after_gift"))
	assert_true(MailState.is_received(&"fixture_after_talk"))
	assert_true(MailState.is_received(&"fixture_after_gift"))

func test_mail_flags_round_trip_through_world_state() -> void:
	WorldClock.set_time(2, 8 * 60)
	MailState.refresh_deliveries()
	assert_true(MailState.mark_read(WELCOME))
	assert_true(MailState.claim_rewards(WELCOME))
	var saved := WorldState.to_save_data()
	WorldState.clear()
	assert_false(MailState.is_received(WELCOME))
	WorldState.load_save_data(saved)
	assert_true(MailState.is_received(WELCOME))
	assert_true(MailState.is_read(WELCOME))
	assert_true(MailState.is_claimed(WELCOME))

func test_world_flag_mail_delivers_immediately_without_waiting_for_next_day() -> void:
	assert_false(MailState.is_received(&"fixture_garden_restored"))
	WorldState.set_value(GARDEN_FLAG, true)
	assert_true(MailState.is_received(&"fixture_garden_restored"))
	assert_true(MailState.get_unread_mail().any(func(mail: MailData) -> bool: return mail.id == &"fixture_garden_restored"))

func test_world_writes_are_checked_once_by_the_next_frame() -> void:
	var received_key := &"mail:fixture_garden_restored:received"
	WorldState.set_value(GARDEN_FLAG, true)
	WorldState.set_value(&"fixture_unrelated", 1)
	assert_false(WorldState.get_bool(received_key), "a burst of writes waits for one check")
	await get_tree().process_frame
	assert_true(WorldState.get_bool(received_key))

func test_a_load_drops_the_check_that_writes_before_it_waited_for() -> void:
	WorldState.set_value(&"fixture_unrelated", 1)
	WorldState.load_save_data({String(GARDEN_FLAG): true})
	await get_tree().process_frame
	assert_false(MailState.is_received(&"fixture_garden_restored"), "a loaded world already holds which letters arrived")

func test_mail_delivers_once_the_friendship_reaches_its_hearts() -> void:
	RelationshipState.add_friendship(&"fixture_npc", RelationshipManager.POINTS_PER_HEART)
	assert_false(MailState.is_received(&"fixture_friend"))
	RelationshipState.add_friendship(&"fixture_npc", RelationshipManager.POINTS_PER_HEART)
	assert_true(MailState.is_received(&"fixture_friend"))

func test_mail_delivers_from_live_quest_completion() -> void:
	assert_false(MailState.is_received(&"fixture_after_hoard"))
	assert_true(QuestState.start_quest(&"fixture_hoard_quest"))
	for item_id: StringName in [&"fixture_seeds", &"fixture_twig", &"fixture_pebble"]:
		InventoryState.add_item_by_id(item_id, 1)
	assert_true(QuestState.is_completed(&"fixture_hoard_quest"))
	assert_true(MailState.is_received(&"fixture_after_hoard"))

func test_mail_condition_gates_delivery() -> void:
	var mail := MailData.new()
	mail.id = &"rules_test_mail"
	mail.condition = "WORLD_FLAG test:rules_flag"
	assert_false(mail.is_available(1))
	WorldState.set_value(&"test:rules_flag", true)
	assert_true(mail.is_available(1))

## Letters from `fixture_npc`: one dated on day 2 with seeds in it, one for
## each of three quests, one for a world flag and one for two hearts.
func _content() -> Array:
	var npc := NpcProfileData.new()
	npc.id = &"fixture_npc"
	npc.display_name = "Fixture"
	var welcome := _mail(WELCOME)
	welcome.condition = "DAY_AT_LEAST 2"
	welcome.reward_items = {"fixture_seeds": 3}
	var after_talk := _mail(&"fixture_after_talk")
	after_talk.condition = "QUEST_COMPLETED fixture_talk_quest"
	var after_gift := _mail(&"fixture_after_gift")
	after_gift.condition = "QUEST_COMPLETED fixture_gift_quest"
	var after_hoard := _mail(&"fixture_after_hoard")
	after_hoard.condition = "QUEST_COMPLETED fixture_hoard_quest"
	var garden := _mail(&"fixture_garden_restored")
	garden.condition = "WORLD_FLAG %s" % GARDEN_FLAG
	var friend := _mail(&"fixture_friend")
	friend.condition = "HEARTS fixture_npc 2"
	var hoard := _quest(&"fixture_hoard_quest", &"InventoryState.changed")
	hoard.objectives[0].measure = &"InventoryState.get_used_slots"
	hoard.objectives[0].required_amount = 3
	return [
		npc, welcome, after_talk, after_gift, after_hoard, garden, friend,
		_quest(&"fixture_talk_quest", &"NpcSocialEvents.npc_talked"),
		_quest(&"fixture_gift_quest", &"NpcSocialEvents.gift_given"),
		hoard,
		_item(&"fixture_seeds"),
		_item(&"fixture_twig"),
		_item(&"fixture_pebble"),
	]

func _mail(id: StringName) -> MailData:
	var mail := MailData.new()
	mail.id = id
	mail.sender_npc_id = &"fixture_npc"
	mail.subject = String(id).capitalize()
	mail.body = "A letter."
	return mail

func _quest(id: StringName, event: StringName) -> QuestData:
	var quest := QuestData.new()
	quest.id = id
	quest.title = String(id).capitalize()
	var objective := QuestObjective.new()
	objective.event = event
	quest.objectives = [objective]
	return quest

func _item(id: StringName) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	return item
