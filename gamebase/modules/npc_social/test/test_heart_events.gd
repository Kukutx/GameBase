extends GutTest

class FakeAiProvider:
	extends Node
	func start_conversation(_npc: GameNpc, _actor: Node, _context: Dictionary) -> void:
		pass

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
	InputLock.unlock(GameConversationService.DIALOGUE_LOCK)
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

func test_heart_event_priority_disables_ai_and_daily_title_falls_back_safely() -> void:
	var service := GameConversationService.new()
	var provider := FakeAiProvider.new()
	add_child_autofree(service)
	add_child_autofree(provider)
	service.prefer_ai = true
	service.ai_provider = provider
	var profile := NpcProfileData.new()
	profile.ai_enabled = true
	profile.dialogue_titles_by_hearts = {2: "missing_friend_title"}
	var event := HeartEventData.new()
	event.id = &"test_heart_event"
	event.dialogue_title = "heart_2"
	assert_true(bool(service.call("_can_use_ai", profile, null)))
	assert_false(bool(service.call("_can_use_ai", profile, event)))

	var dialogue := _dialogue()
	assert_eq(String(service.call("_resolve_daily_title", dialogue, profile, "start", 2)), "start")
	assert_true(bool(service.call("_dialogue_has_key", dialogue, "heart_2")))
	assert_false(bool(service.call("_dialogue_has_key", dialogue, "definitely_missing_title")))

func test_heart_event_seen_commits_on_dialogue_end_not_interrupted_balloon_exit() -> void:
	var event := _two_hearts_event()
	var dialogue := _dialogue()
	var service := GameConversationService.new()
	add_child_autofree(service)
	assert_false(HeartEvents.is_seen(event.id))

	service.set("_active_balloon_id", 7001)
	service.set("_active_heart_event", event)
	service.set("_active_heart_dialogue", dialogue)
	service.call("_on_scripted_balloon_exited", 7001)
	assert_false(HeartEvents.is_seen(event.id))
	assert_null(service.get("_active_heart_event"))

	service.set("_active_heart_event", event)
	service.set("_active_heart_dialogue", dialogue)
	service.call("_on_dialogue_ended", dialogue)
	assert_true(HeartEvents.is_seen(event.id))
	assert_true(bool(NpcMemory.get_facts(&"fixture_npc").get("heart_event:fixture_npc_two_hearts", false)))

func test_a_conversation_holds_the_controls_until_its_dialogue_ends_or_its_balloon_goes() -> void:
	var service := GameConversationService.new()
	add_child_autofree(service)
	var dialogue := _dialogue()
	var balloon := Node.new()
	add_child_autofree(balloon)
	service.call("_hold_controls", balloon, dialogue)
	assert_true(InputLock.is_held(GameConversationService.DIALOGUE_LOCK))
	service.call("_on_dialogue_ended", _dialogue())
	assert_true(InputLock.is_held(GameConversationService.DIALOGUE_LOCK), "another dialogue's end is not this one's")
	service.call("_on_dialogue_ended", dialogue)
	assert_false(InputLock.is_held(GameConversationService.DIALOGUE_LOCK), "its end gives the controls back")

	var next_balloon := Node.new()
	add_child(next_balloon)
	service.call("_hold_controls", next_balloon, dialogue)
	assert_true(InputLock.is_held(GameConversationService.DIALOGUE_LOCK))
	next_balloon.free()
	assert_false(InputLock.is_held(GameConversationService.DIALOGUE_LOCK), "a balloon that goes before its dialogue ends gives them back too")
	assert_null(service.get("_active_dialogue"))

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
