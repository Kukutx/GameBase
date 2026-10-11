extends GutTest

## Farm1's NPCs, their dialogue and their heart events. How heart events match,
## are seen and take priority in a conversation is tested with the NPC social
## module.

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
	WorldState.load_save_data(_world_snapshot)
	RelationshipState.load_save_data(_relationship_snapshot)
	NpcMemory.load_save_data(_memory_snapshot)
	WorldClock.load_save_data(_clock_snapshot)

func test_all_core_npcs_have_friendship_dialogue_stages_through_ten_hearts() -> void:
	for npc_id: StringName in [&"mira", &"rowan", &"neri"]:
		var profile := NpcProfileData.find(npc_id)
		assert_not_null(profile)
		assert_eq(profile.get_dialogue_title("start", 0), "start")
		assert_eq(profile.get_dialogue_title("start", 2), "friend_2")
		assert_eq(profile.get_dialogue_title("start", 4), "friend_4")
		assert_eq(profile.get_dialogue_title("start", 6), "friend_6")
		assert_eq(profile.get_dialogue_title("start", 8), "friend_8")
		assert_eq(profile.get_dialogue_title("start", 10), "friend_10")

func test_authored_dialogue_is_translated_at_runtime() -> void:
	var previous := TranslationServer.get_locale()
	TranslationServer.set_locale("zh_CN")
	await get_tree().process_frame

	var cases := [
		{
			"path": "res://game/dialogue/intro.dialogue",
			"line": "欢迎来到起始镇。看到那座老农场重新有了动静，真不错。",
			"response": "我该从哪里开始？",
			"character": "Mira",
			"character_zh": "米拉",
		},
		{
			"path": "res://game/dialogue/neri.dialogue",
			"line": "港口醒了。鱼可不会等爱睡懒觉的人。",
			"response": "今天什么鱼咬钩？",
			"character": "Neri",
			"character_zh": "奈莉",
		},
		{
			"path": "res://game/dialogue/rowan.dialogue",
			"line": "桥还撑得住。按我的标准，这就算好日子。",
			"response": "你在忙什么？",
			"character": "Rowan",
			"character_zh": "罗文",
		},
	]
	for data: Dictionary in cases:
		var dialogue := load(String(data["path"])) as DialogueResource
		assert_not_null(dialogue)
		if dialogue == null:
			continue
		var line := await dialogue.get_next_dialogue_line("start")
		assert_not_null(line)
		if line == null:
			continue
		assert_eq(line.text, String(data["line"]))
		assert_gt(line.responses.size(), 0)
		if not line.responses.is_empty():
			assert_eq((line.responses[0] as DialogueResponse).text, String(data["response"]))
		assert_eq(TranslationServer.translate(String(data["character"]), &"dialogue"), String(data["character_zh"]))
		# Dialogue Manager injects the DialogueResource into extra_game_states as
		# `self`. Clear the test-only resolved line state so the resource cache can
		# release cleanly before the headless test process exits.
		line.extra_game_states.clear()
		for raw_id: Variant in dialogue.lines.keys():
			var raw_line: Variant = dialogue.lines[raw_id]
			if raw_line is Dictionary:
				(raw_line as Dictionary).erase("resource")

	TranslationServer.set_locale(previous)

func test_authored_daily_and_heart_event_titles_exist_in_dialogue_resources() -> void:
	var dialogue_by_npc := {
		"mira": load("res://game/dialogue/intro.dialogue") as DialogueResource,
		"rowan": load("res://game/dialogue/rowan.dialogue") as DialogueResource,
		"neri": load("res://game/dialogue/neri.dialogue") as DialogueResource,
	}
	for npc_id: StringName in [&"mira", &"rowan", &"neri"]:
		var profile := NpcProfileData.find(npc_id)
		var dialogue: DialogueResource = dialogue_by_npc[String(npc_id)]
		assert_not_null(profile)
		assert_not_null(dialogue)
		if profile == null or dialogue == null:
			continue
		for hearts: int in [0, 2, 4, 6, 8, 10]:
			var title := profile.get_dialogue_title("start", hearts)
			assert_true(dialogue.cues.has(title), "%s daily dialogue cue '%s' is missing" % [String(npc_id), title])
	for event: HeartEventData in HeartEventData.find_all():
		var dialogue: DialogueResource = dialogue_by_npc.get(String(event.npc_id))
		assert_not_null(dialogue)
		if dialogue != null:
			assert_true(dialogue.cues.has(event.dialogue_title), "%s heart-event cue '%s' is missing" % [String(event.id), event.dialogue_title])

func test_mira_two_hearts_plays_in_starter_town_during_the_day_at_two_hearts() -> void:
	var event := HeartEventData.find(&"mira_two_hearts")
	assert_not_null(event)
	if event == null:
		return
	assert_true(event.matches(&"mira", 2, &"starter_town", 1, 10 * 60))
	assert_false(event.matches(&"mira", 1, &"starter_town", 1, 10 * 60))
	assert_false(event.matches(&"rowan", 2, &"starter_town", 1, 10 * 60))
	assert_false(event.matches(&"mira", 2, &"riverside_town", 1, 10 * 60))
	assert_false(event.matches(&"mira", 2, &"starter_town", 1, 19 * 60))

func test_manifest_contains_five_heart_events_for_each_core_npc() -> void:
	var by_npc: Dictionary = {}
	for event: HeartEventData in HeartEventData.find_all():
		var key := String(event.npc_id)
		var tiers: Array = by_npc.get(key, [])
		tiers.append(event.required_hearts)
		by_npc[key] = tiers
	assert_eq(HeartEventData.find_all().size(), 15)
	for npc_id: String in ["mira", "rowan", "neri"]:
		var tiers: Array = by_npc.get(npc_id, [])
		tiers.sort()
		assert_eq(tiers, [2, 4, 6, 8, 10], "%s is missing a friendship event tier" % npc_id)

func test_mid_and_capstone_heart_events_respect_town_progress_flags() -> void:
	var mira_four := HeartEventData.find(&"mira_four_hearts")
	var rowan_four := HeartEventData.find(&"rowan_four_hearts")
	var neri_four := HeartEventData.find(&"neri_four_hearts")
	var mira_ten := HeartEventData.find(&"mira_ten_hearts")
	assert_not_null(mira_four)
	assert_not_null(rowan_four)
	assert_not_null(neri_four)
	assert_not_null(mira_ten)
	assert_false(mira_four.matches(&"mira", 4, &"starter_town", 1, 10 * 60))
	WorldState.set_value(&"project:starter_garden:complete", true)
	assert_true(mira_four.matches(&"mira", 4, &"starter_town", 1, 10 * 60))
	assert_false(rowan_four.matches(&"rowan", 4, &"riverside_town", 1, 10 * 60))
	WorldState.set_value(&"project:riverside_workshop:complete", true)
	assert_true(rowan_four.matches(&"rowan", 4, &"riverside_town", 1, 10 * 60))
	assert_true(neri_four.matches(&"neri", 4, &"harbor_town", 1, 10 * 60))
	assert_false(mira_ten.matches(&"mira", 10, &"starter_town", 1, 19 * 60))
	WorldState.set_value(&"project:harbor_supply:complete", true)
	assert_true(mira_ten.matches(&"mira", 10, &"starter_town", 1, 19 * 60))
