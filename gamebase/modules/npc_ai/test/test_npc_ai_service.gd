extends GutTest

## How `NpcAi` answers chat requests: one at a time in order, from the model
## when there is one the player allows, else or when it fails or is slow from
## the rules, and with the memory split into the latest talk and what bears on
## the topic.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

class HeldProvider:
	extends NpcAiProvider
	## Lets the request asked first go.
	signal release
	var asked: Array[StringName] = []
	var answer := "A line from the model."
	func get_source() -> StringName:
		return &"fixture_model"
	func reply(request: NpcAiRequest) -> String:
		asked.append(request.npc_id)
		await release
		return answer

class SilentProvider:
	extends NpcAiProvider
	func reply(_request: NpcAiRequest) -> String:
		return ""

var _memory: Dictionary
var _online: bool

func before_each() -> void:
	_memory = NpcMemory.to_save_data()
	_online = GameSettings.online_services
	NpcMemory.clear()
	ContentFixture.use(self, [_npc(&"fixture_ann"), _npc(&"fixture_bo"), _topic()])

func after_each() -> void:
	NpcAi.provider = null
	NpcAi.cancel_all()
	GameSettings.online_services = _online
	ContentRegistry.active = ContentDB
	NpcMemory.load_save_data(_memory)

func test_without_a_model_the_rules_answer_at_once() -> void:
	var request := NpcAi.ask(&"fixture_ann")
	assert_true(request.is_done())
	assert_eq(request.source, NpcAiService.SOURCE_RULES)
	assert_eq(await request.wait(), "Hello! I'm Fixture Ann. Nice to meet you.")

func test_requests_are_answered_one_at_a_time_in_the_order_they_come() -> void:
	var held := HeldProvider.new()
	NpcAi.provider = held
	var first := NpcAi.ask(&"fixture_ann")
	var second := NpcAi.ask(&"fixture_bo", ChatTopicData.find(&"fixture_weather"))
	assert_eq(held.asked, [&"fixture_ann"] as Array[StringName], "the second waits for the first")
	held.release.emit()
	assert_true(first.is_done())
	assert_eq(first.text, "A line from the model.")
	assert_eq(first.source, &"fixture_model")
	assert_eq(held.asked, [&"fixture_ann", &"fixture_bo"] as Array[StringName], "then the second is asked")
	assert_false(second.is_done())
	held.release.emit()
	assert_true(second.is_done())

func test_a_model_that_is_slow_or_answers_nothing_gives_way_to_the_rules() -> void:
	var settings := NpcAiSettings.new()
	settings.timeout_seconds = 0.05
	ContentFixture.use_settings(self, [settings])
	var held := HeldProvider.new()
	NpcAi.provider = held
	var slow := NpcAi.ask(&"fixture_ann")
	assert_false(slow.is_done())
	await wait_until(slow.is_done, 1.0)
	assert_eq(slow.source, NpcAiService.SOURCE_RULES)
	assert_eq(slow.text, "Hello! I'm Fixture Ann. Nice to meet you.")
	held.release.emit()
	assert_eq(slow.source, NpcAiService.SOURCE_RULES, "a late line changes nothing")
	NpcAi.provider = SilentProvider.new()
	await wait_until(func() -> bool: return not NpcAi.is_busy(), 1.0)
	var silent := NpcAi.ask(&"fixture_bo")
	assert_true(silent.is_done())
	assert_eq(silent.source, NpcAiService.SOURCE_RULES)

func test_requests_not_started_on_are_dropped_and_a_cancelled_one_is_skipped() -> void:
	var held := HeldProvider.new()
	NpcAi.provider = held
	var first := NpcAi.ask(&"fixture_ann")
	var second := NpcAi.ask(&"fixture_bo")
	var third := NpcAi.make_request(&"fixture_bo")
	NpcAi.cancel_all()
	assert_true(second.is_cancelled())
	held.release.emit()
	assert_true(first.is_done(), "the one started on still gets its answer")
	assert_false(second.is_done())
	third.cancel()
	NpcAi.submit(third)
	assert_false(third.is_done())
	assert_eq(held.asked, [&"fixture_ann"] as Array[StringName])

func test_a_request_given_up_while_it_is_answered_lets_the_next_go_at_once() -> void:
	var held := HeldProvider.new()
	NpcAi.provider = held
	var first := NpcAi.ask(&"fixture_ann")
	var second := NpcAi.ask(&"fixture_bo")
	first.cancel()
	assert_eq(held.asked, [&"fixture_ann", &"fixture_bo"] as Array[StringName], "the next is asked without waiting for the first's answer")
	assert_eq(await first.wait(), "", "nobody waits for a request given up")
	held.release.emit()
	assert_false(first.is_done(), "a late answer is dropped")
	assert_true(second.is_done())
	assert_eq(second.text, "A line from the model.")

func test_the_game_s_endpoint_answers_only_once_the_player_allows_online_services() -> void:
	var settings := NpcAiSettings.new()
	settings.endpoint = "https://chat.example/v1/chat/completions"
	settings.model = "fixture-model"
	ContentFixture.use_settings(self, [settings])
	GameSettings.online_services = false
	assert_null(NpcAi.get_online_provider())
	GameSettings.online_services = true
	assert_is(NpcAi.get_online_provider(), NpcHttpProvider)
	settings.endpoint = ""
	assert_null(NpcAi.get_online_provider(), "no endpoint, no network")

func test_a_request_carries_the_latest_talk_and_the_older_messages_that_bear_on_the_topic() -> void:
	var settings := NpcAiSettings.new()
	settings.recent_messages = 2
	settings.recalled_messages = 1
	ContentFixture.use_settings(self, [settings])
	for text: String in ["The rain was heavy.", "I like the weather in spring.", "Nice hat.", "Thanks!"]:
		NpcMemory.append_message(&"fixture_ann", &"player", text)
	var request := NpcAi.make_request(&"fixture_ann", ChatTopicData.find(&"fixture_weather"))
	assert_eq(request.player_text, "How's the weather?")
	assert_eq(request.recent.map(func(message: Dictionary) -> String: return message["text"]), ["Nice hat.", "Thanks!"])
	assert_eq(request.recalled.map(func(message: Dictionary) -> String: return message["text"]), ["I like the weather in spring."])
	assert_eq(request.context["npc"]["id"], "fixture_ann")

static func _npc(id: StringName) -> NpcProfileData:
	var profile := NpcProfileData.new()
	profile.id = id
	profile.display_name = String(id).trim_prefix("fixture_").capitalize().insert(0, "Fixture ")
	profile.ai_enabled = true
	return profile

static func _topic() -> ChatTopicData:
	var topic := ChatTopicData.new()
	topic.id = &"fixture_weather"
	topic.title = "How's the weather?"
	topic.rule_replies = PackedStringArray(["It is {weather} out."])
	return topic
