extends GutTest

## What an NPC chats with: the rules a game writes (`NpcRuleProvider`), what a
## language model is asked (`NpcAiPrompt`) and how an endpoint is called and
## read (`NpcHttpProvider`).

func test_the_greeting_follows_the_moment() -> void:
	var rules := NpcRuleProvider.new()
	assert_eq(rules.greeting(_context({}, [])), "Hello! I'm Fixture. Nice to meet you.", "a first meeting")
	assert_eq(rules.greeting(_after_talk({}, 5)), "Back again? What's on your mind?", "a second talk today")
	assert_eq(rules.greeting(_after_talk({}, 1)), "Good morning!", "four days on, in the morning")
	assert_eq(rules.greeting(_after_talk({"minute_of_day": 19 * 60}, 4)), "Good evening!")
	assert_eq(rules.greeting(_after_talk({"day": 12}, 4)), "It's been a while! Good to see you.")
	assert_eq(rules.greeting(_context({}, [_message("npc", "Hi.", 5)])), "Hello! I'm Fixture. Nice to meet you.", "messages alone are no earlier talk: a talk is")
	var birthday := _context({}, [])
	birthday["npc"]["birthday_today"] = true
	assert_eq(rules.greeting(birthday), "It's my birthday today! Thanks for stopping by.")

func test_a_topic_answer_is_a_rule_reply_whose_placeholders_have_values() -> void:
	var rules := NpcRuleProvider.new()
	var topic := _topic(["On today: {event}.", "I'm the {role} around {location}."])
	assert_eq(rules.answer(topic, _context({}, [])), "I'm the Baker around Fixture Square.", "no event is on, so its reply is left out")
	var context := _context({}, [])
	context["active_events"] = [{"id": "fair", "name": "Fixture Fair"}]
	var answers := {}
	for salt in 12:
		answers[rules.answer(topic, context, salt)] = true
	assert_eq(answers.size(), 2, "with an event on, either reply may come")
	assert_eq(rules.answer(topic, context, 3), rules.answer(topic, context, 3), "the same talk gets the same reply")
	assert_eq(rules.answer(_topic(["{event} today!"]), _context({}, [])), "Hmm, I couldn't say.", "a shrug when no reply fits")

func test_the_prompt_makes_the_model_the_npc_and_takes_turns_from_the_player() -> void:
	var request := NpcAiRequest.new()
	request.context = _context({}, [])
	request.locale = "en"
	request.recalled.assign([_message("player", "I love fishing.", 2)])
	request.recent.assign([_message("npc", "Morning.", 5), _message("player", "Hi!", 5), _message("player", "Nice day.", 5), _message("npc", "It is.", 5)])
	var instructions := NpcAiPrompt.instructions(request)
	for expected: String in ["You are Fixture", "Baker", "Kind and curious.", "day 5", "Fixture Square", "3 of 10 hearts", "- day 2, the player: I love fishing.", "Answer in English"]:
		assert_string_contains(instructions, expected)
	assert_eq(NpcAiPrompt.messages(request), [
		{"role": "user", "content": "Hi!\nNice day."},
		{"role": "assistant", "content": "It is."},
		{"role": "user", "content": NpcAiPrompt.GREETING_TURN},
	] as Array[Dictionary], "the NPC's opening line goes, the player's two lines join, the greeting turn ends it")
	request.topic = _topic(["Fine."])
	request.player_text = "How are you?"
	assert_eq(NpcAiPrompt.messages(request).back(), {"role": "user", "content": "How are you?"})

func test_an_openai_style_endpoint_gets_the_instructions_first_and_its_reply_is_read() -> void:
	var settings := _settings(NpcHttpProvider.FORMAT_OPENAI)
	var provider := NpcHttpProvider.new(settings)
	var sent := []
	provider.send = func(url: String, headers: PackedStringArray, body: String) -> Dictionary:
		sent.append([url, headers, JSON.parse_string(body)])
		return {"code": 200, "body": JSON.stringify({"choices": [{"message": {"role": "assistant", "content": "Lovely day!"}}]})}
	assert_eq(await provider.reply(_request()), "Lovely day!")
	assert_eq(sent[0][0], "https://chat.example/v1/chat/completions")
	assert_false(Array(sent[0][1]).any(func(header: String) -> bool: return header.begins_with("Authorization")), "no key, no header")
	var body: Dictionary = sent[0][2]
	assert_eq(body["model"], "fixture-model")
	assert_eq(body["messages"][0]["role"], "system")
	assert_eq(body["messages"].back(), {"role": "user", "content": "How are you?"})

func test_an_anthropic_style_endpoint_gets_the_instructions_apart_and_its_text_blocks_are_read() -> void:
	var provider := NpcHttpProvider.new(_settings(NpcHttpProvider.FORMAT_ANTHROPIC))
	var sent := []
	provider.send = func(_url: String, headers: PackedStringArray, body: String) -> Dictionary:
		sent.append([headers, JSON.parse_string(body)])
		return {"code": 200, "body": JSON.stringify({"content": [{"type": "text", "text": "Lovely "}, {"type": "text", "text": "day!"}]})}
	assert_eq(await provider.reply(_request()), "Lovely day!")
	assert_true(Array(sent[0][0]).has("anthropic-version: " + NpcHttpProvider.ANTHROPIC_VERSION))
	var body: Dictionary = sent[0][1]
	assert_true(String(body["system"]).begins_with("You are Fixture"))
	assert_eq(body["messages"][0]["role"], "user", "the instructions are no message")

func test_a_failed_or_unreadable_answer_is_no_line() -> void:
	var provider := NpcHttpProvider.new(_settings(NpcHttpProvider.FORMAT_OPENAI))
	for response: Dictionary in [{"code": 500, "body": "{}"}, {"code": 0, "body": ""}, {"code": 200, "body": "not json"}, {"code": 200, "body": "{\"choices\": []}"}]:
		provider.send = func(_url: String, _headers: PackedStringArray, _body: String) -> Dictionary: return response
		assert_eq(await provider.reply(_request()), "", "for %s" % response)
	assert_eq(NpcHttpProvider.read_reply("{\"content\": [{\"type\": \"tool_use\"}]}", NpcHttpProvider.FORMAT_ANTHROPIC), "")

func test_an_answer_cut_off_at_the_token_limit_keeps_its_whole_sentences() -> void:
	var openai := {"choices": [{"message": {"content": "Lovely day! The river is hi"}, "finish_reason": "length"}]}
	assert_eq(NpcHttpProvider.read_reply(JSON.stringify(openai), NpcHttpProvider.FORMAT_OPENAI), "Lovely day!")
	openai["choices"][0]["finish_reason"] = "stop"
	assert_eq(NpcHttpProvider.read_reply(JSON.stringify(openai), NpcHttpProvider.FORMAT_OPENAI), "Lovely day! The river is hi", "an answer that ended is kept whole")
	var anthropic := {"content": [{"type": "text", "text": "今天天气很好。河水涨"}], "stop_reason": "max_tokens"}
	assert_eq(NpcHttpProvider.read_reply(JSON.stringify(anthropic), NpcHttpProvider.FORMAT_ANTHROPIC), "今天天气很好。")
	anthropic["content"][0]["text"] = "The river is hi"
	assert_eq(NpcHttpProvider.read_reply(JSON.stringify(anthropic), NpcHttpProvider.FORMAT_ANTHROPIC), "", "no whole sentence, no line")

func test_a_request_goes_only_to_an_https_endpoint_or_an_http_one_on_this_machine() -> void:
	var settings := NpcAiSettings.new()
	for endpoint: String in ["https://chat.example/v1", "http://localhost:8080/v1", "http://127.0.0.1/v1", "http://[::1]:11434/api", "http://LOCALHOST"]:
		settings.endpoint = endpoint
		assert_true(settings.is_endpoint_safe(), endpoint)
	for endpoint: String in ["http://chat.example/v1", "http://localhost.chat.example/v1", "http://127.0.0.1.chat.example/", "http://localhost@chat.example/", "ftp://localhost/", "https://", "chat.example"]:
		settings.endpoint = endpoint
		assert_false(settings.is_endpoint_safe(), endpoint)
	settings.endpoint = "http://localhost.chat.example/v1"
	settings.model = "fixture-model"
	assert_eq(settings.find_problems(ContentRegistry.active), PackedStringArray(["endpoint 'http://localhost.chat.example/v1' is neither an https:// URL nor an http:// one on this machine"]))

# What an NPC knows, as `NpcContext` builds it: day 5 at ten, with `world`'s
# fields over those, and no module's facts.
func _context(world: Dictionary, messages: Array) -> Dictionary:
	var base_world := {"day": 5, "minute_of_day": 10 * 60, "time_text": "10:00", "season": "Spring", "weather": "Sunny", "location_name": "Fixture Square"}
	base_world.merge(world, true)
	return {
		"npc": {"id": "fixture", "name": "Fixture", "role": "Baker", "personality": "Kind and curious.", "birthday_today": false},
		"relationship": {"hearts": 3},
		"world": base_world,
		"npc_state": {"activity": ""},
		"memory": {"facts": {}, "recent_messages": messages},
	}

# What an NPC knows when the player last talked to it on `day`.
func _after_talk(world: Dictionary, day: int) -> Dictionary:
	var context := _context(world, [])
	context["memory"]["facts"]["previous_talk_day"] = day
	return context

func _message(role: String, text: String, day: int) -> Dictionary:
	return {"role": role, "text": text, "day": day}

func _topic(replies: Array) -> ChatTopicData:
	var topic := ChatTopicData.new()
	topic.id = &"fixture_topic"
	topic.title = "How are you?"
	topic.rule_replies = PackedStringArray(replies)
	return topic

func _request() -> NpcAiRequest:
	var request := NpcAiRequest.new()
	request.context = _context({}, [])
	request.locale = "en"
	request.topic = _topic(["Fine."])
	request.player_text = "How are you?"
	return request

func _settings(format: StringName) -> NpcAiSettings:
	var settings := NpcAiSettings.new()
	settings.endpoint = "https://chat.example/v1/chat/completions"
	settings.model = "fixture-model"
	settings.api_format = format
	return settings
