extends GutTest

const DIALOGUE_TEXT := """~ start
Fixture: Good morning.
=> END

~ heart_2
Fixture: Walk with me for a minute?
=> END
"""

var _world_snapshot: Dictionary
var _relationship_snapshot: Dictionary
var _clock_snapshot: Dictionary
var _memory_snapshot: Dictionary

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_relationship_snapshot = RelationshipState.to_save_data()
	_clock_snapshot = WorldClock.to_save_data()
	_memory_snapshot = NpcMemory.to_save_data()
	WorldState.clear()
	RelationshipState.clear()
	NpcMemory.clear()
	WorldClock.set_time(1, 10 * 60)

func after_each() -> void:
	InputLock.unlock(DialogueService.LOCK)
	WorldState.load_save_data(_world_snapshot)
	RelationshipState.load_save_data(_relationship_snapshot)
	NpcMemory.load_save_data(_memory_snapshot)
	WorldClock.load_save_data(_clock_snapshot)

func test_daily_dialogue_title_follows_the_highest_heart_threshold_reached() -> void:
	var profile := NpcProfileData.new()
	profile.dialogue_titles_by_hearts = {2: "friend_2", 6: "friend_6", 11: "out_of_range", 4: ""}
	assert_eq(profile.get_dialogue_title("start", 0), "start")
	assert_eq(profile.get_dialogue_title("start", 2), "friend_2")
	assert_eq(profile.get_dialogue_title("start", 5), "friend_2", "an empty title is skipped")
	assert_eq(profile.get_dialogue_title("start", 10), "friend_6", "a threshold above ten hearts is ignored")

func test_an_npc_chats_only_when_it_allows_it_and_a_module_makes_chats_and_titles_fall_back_safely() -> void:
	var service := GameConversationService.new()
	add_child_autofree(service)
	var profile := NpcProfileData.new()
	profile.dialogue_titles_by_hearts = {2: "missing_friend_title"}
	assert_false(service.chats(profile), "no module makes chats")
	service.chat_maker = func(_npc: GameNpc, _actor: Node) -> DialogueChat: return DialogueChat.new()
	assert_false(service.chats(profile), "the NPC does not chat")
	profile.ai_enabled = true
	assert_true(service.chats(profile))

	var dialogue := _dialogue()
	assert_eq(String(service.call("_resolve_daily_title", dialogue, profile, "start", 2)), "start")

func test_a_heart_event_is_seen_once_its_dialogue_ends_not_when_its_balloon_goes_first() -> void:
	var event := _two_hearts_event()
	var dialogue := _dialogue()
	var service := GameConversationService.new()
	add_child_autofree(service)
	assert_false(HeartEvents.is_seen(event.id))

	service.set("_heart_event", event)
	service.set("_heart_dialogue", dialogue)
	service.call("_forget_heart_event")
	Dialogue.finished.emit(dialogue)
	assert_false(HeartEvents.is_seen(event.id), "a balloon gone before the end leaves it unseen")

	service.set("_heart_event", event)
	service.set("_heart_dialogue", dialogue)
	Dialogue.finished.emit(_dialogue())
	assert_false(HeartEvents.is_seen(event.id), "another dialogue's end is not the event's")
	Dialogue.finished.emit(dialogue)
	assert_true(HeartEvents.is_seen(event.id))
	assert_true(bool(NpcMemory.get_facts(&"fixture_npc").get("heart_event:fixture_npc_two_hearts", false)))
	assert_null(service.get("_heart_event"))

func test_heart_events_match_only_their_npc_location_time_hearts_and_condition() -> void:
	var event := _two_hearts_event()
	assert_true(event.matches(&"fixture_npc", 2, &"fixture_square", 1, 10 * 60))
	assert_false(event.matches(&"fixture_npc", 1, &"fixture_square", 1, 10 * 60))
	assert_false(event.matches(&"fixture_other_npc", 2, &"fixture_square", 1, 10 * 60))
	assert_false(event.matches(&"fixture_npc", 2, &"fixture_harbor", 1, 10 * 60))
	assert_false(event.matches(&"fixture_npc", 2, &"fixture_square", 1, 19 * 60))

	event.condition = "WORLD_FLAG fixture_garden_restored"
	assert_false(event.matches(&"fixture_npc", 2, &"fixture_square", 1, 10 * 60))
	WorldState.set_value(&"fixture_garden_restored", true)
	assert_true(event.matches(&"fixture_npc", 2, &"fixture_square", 1, 10 * 60))
	event.condition = "WEEKDAY 1"
	assert_false(event.matches(&"fixture_npc", 2, &"fixture_square", 1, 10 * 60), "the condition is asked about the event's day")
	assert_true(event.matches(&"fixture_npc", 2, &"fixture_square", 2, 10 * 60))

func test_heart_event_seen_state_uses_world_state_and_npc_memory() -> void:
	var event := _two_hearts_event()
	assert_false(HeartEvents.is_seen(event.id))
	HeartEvents.mark_seen(event)
	assert_true(HeartEvents.is_seen(event.id))
	assert_true(bool(NpcMemory.get_facts(&"fixture_npc").get("heart_event:fixture_npc_two_hearts", false)))

	var saved_world := WorldState.to_save_data()
	WorldState.clear()
	assert_false(HeartEvents.is_seen(event.id))
	WorldState.load_save_data(saved_world)
	assert_true(HeartEvents.is_seen(event.id))

## An event of `fixture_npc` at two hearts, in `fixture_square` from 9:00 to 18:00.
func _two_hearts_event() -> HeartEventData:
	var event := HeartEventData.new()
	event.id = &"fixture_npc_two_hearts"
	event.npc_id = &"fixture_npc"
	event.required_hearts = 2
	event.dialogue_title = "heart_2"
	event.location_id = &"fixture_square"
	event.start_minute = 9 * 60
	event.end_minute = 18 * 60
	return event

func _dialogue() -> DialogueResource:
	return DialogueManager.create_resource_from_text(DIALOGUE_TEXT) as DialogueResource
