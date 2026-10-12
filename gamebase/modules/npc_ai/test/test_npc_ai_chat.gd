extends GutTest

## Talking to an NPC that chats (`NpcAiChat` through `ConversationService`):
## its greeting, the topics and the goodbye as responses, the answer to a topic
## kept in its memory, the world paused until the chat ends, a due heart event
## first, and nothing kept of a line the chat no longer waits for.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

class HeldProvider:
	extends NpcAiProvider
	signal release
	func reply(_request: NpcAiRequest) -> String:
		await release
		return "A line from the model."

const HEART_DIALOGUE := """~ start
Fixture: Morning.
=> END

~ heart_0
Fixture: Can I tell you something?
=> END
"""

var _memory: Dictionary
var _relationships: Dictionary
var _clock: Dictionary

func before_each() -> void:
	_memory = NpcMemory.to_save_data()
	_relationships = RelationshipState.to_save_data()
	_clock = WorldClock.to_save_data()
	NpcMemory.clear()
	RelationshipState.clear()
	WorldClock.set_time(1, 10 * 60)

func after_each() -> void:
	NpcAi.provider = null
	NpcAi.cancel_all()
	for balloon: Node in _balloons():
		balloon.free()
	InputLock.unlock(DialogueService.LOCK)
	ContentRegistry.active = ContentDB
	NpcMemory.load_save_data(_memory)
	RelationshipState.load_save_data(_relationships)
	WorldClock.load_save_data(_clock)

func test_a_chat_greets_answers_a_topic_and_ends_at_goodbye() -> void:
	ContentFixture.use(self, [_profile(), _topic()])
	ConversationService.start_conversation(_npc(), null, null)
	var balloon := await _balloon()
	assert_eq(balloon.get_line().text, "Hello! I'm Fixture Ann. Nice to meet you.")
	assert_eq(balloon.get_line().character, "Fixture Ann")
	assert_eq(_response_texts(balloon), ["How's it going?", "Goodbye"])
	assert_true(get_tree().paused, "the world waits while they chat")

	await _pick(balloon, 0)
	assert_eq(balloon.get_line().text, "Fine, thanks.")
	assert_eq(NpcMemory.get_recent_messages(&"fixture_ann").map(func(message: Dictionary) -> String: return "%s: %s" % [message["role"], message["text"]]), [
		"npc: Hello! I'm Fixture Ann. Nice to meet you.",
		"player: How's it going?",
		"npc: Fine, thanks.",
	])

	var gone := [false]
	balloon.tree_exited.connect(func() -> void: gone[0] = true)
	await _pick(balloon, 1)
	assert_true(await _until(func() -> bool: return gone[0]), "goodbye ends the chat")
	assert_false(InputLock.is_locked())
	assert_false(get_tree().paused)

func test_a_second_talk_the_same_day_is_greeted_as_one() -> void:
	ContentFixture.use(self, [_profile(), _topic()])
	NpcMemory.remember_fact(&"fixture_ann", &"last_talk_day", WorldClock.day)
	ConversationService.start_conversation(_npc(), null, null)
	var balloon := await _balloon()
	assert_eq(balloon.get_line().text, "Back again? What's on your mind?", "a talk of any kind earlier today counts")

func test_a_due_heart_event_plays_before_the_chat() -> void:
	var event := HeartEventData.new()
	event.id = &"fixture_heart"
	event.npc_id = &"fixture_ann"
	event.required_hearts = 0
	event.dialogue_title = "heart_0"
	ContentFixture.use(self, [_profile(), _topic(), event])
	ConversationService.start_conversation(_npc(), null, DialogueManager.create_resource_from_text(HEART_DIALOGUE) as DialogueResource)
	var balloon := await _balloon()
	assert_eq(balloon.get_line().text, "Can I tell you something?")

func test_a_chat_that_closes_while_its_line_comes_keeps_nothing_of_it() -> void:
	ContentFixture.use(self, [_profile(), _topic()])
	var held := HeldProvider.new()
	NpcAi.provider = held
	ConversationService.start_conversation(_npc(), null, null)
	var balloons := _balloons()
	assert_eq(balloons.size(), 1)
	var balloon := balloons[0] as DialogueBalloon
	var label := balloon.get_node("%LineLabel") as RichTextLabel
	assert_true(await _until(func() -> bool: return label.text == DialogueBalloon.PENDING_TEXT), "the panel shows the line is on its way")
	balloon.free()
	held.release.emit()
	await get_tree().process_frame
	assert_eq(NpcMemory.get_recent_messages(&"fixture_ann").size(), 0)

func _profile() -> NpcProfileData:
	var profile := NpcProfileData.new()
	profile.id = &"fixture_ann"
	profile.display_name = "Fixture Ann"
	profile.ai_enabled = true
	return profile

func _topic() -> ChatTopicData:
	var topic := ChatTopicData.new()
	topic.id = &"fixture_how"
	topic.title = "How's it going?"
	topic.rule_replies = PackedStringArray(["Fine, thanks."])
	return topic

# An NPC of the fixture profile, not in the tree: a conversation reads only its
# id, profile and name.
func _npc() -> GameNpc:
	var npc := GameNpc.new()
	npc.profile = NpcProfileData.find(&"fixture_ann")
	npc.display_name = npc.profile.display_name
	autofree(npc)
	return npc

func _balloons() -> Array[Node]:
	return get_tree().root.find_children("*", "DialogueBalloon", true, false)

# Whether `condition` holds within `seconds`. GUT's own waits stop while the
# world is paused, as it is for a conversation; the tree's frames go on.
func _until(condition: Callable, seconds := 3.0) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not condition.call():
		if Time.get_ticks_msec() > end:
			return false
		await get_tree().process_frame
	return true

# The conversation's balloon, once its first line shows in full.
func _balloon() -> DialogueBalloon:
	await _until(func() -> bool: return _balloons().size() == 1 and (_balloons()[0] as DialogueBalloon).get_line() != null)
	var balloon := _balloons()[0] as DialogueBalloon
	await _until(func() -> bool: return not balloon.is_typing())
	return balloon

func _response_texts(balloon: DialogueBalloon) -> Array:
	return balloon.get_line().responses.map(func(response: DialogueResponse) -> String: return response.text)

# Picks the response at `index` and waits for the line it leads to.
func _pick(balloon: DialogueBalloon, index: int) -> void:
	var line := balloon.get_line()
	await _until(func() -> bool: return balloon.get_node("%Responses").visible)
	(balloon.get_node("%Responses") as DialogueResponsesMenu).response_selected.emit(line.responses[index])
	await _until(func() -> bool: return not is_instance_valid(balloon) or balloon.get_line() != line)
	if is_instance_valid(balloon):
		await _until(func() -> bool: return not balloon.is_typing())
