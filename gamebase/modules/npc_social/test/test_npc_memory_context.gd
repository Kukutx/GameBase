extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

func test_npc_memory_is_bounded_and_round_trips() -> void:
	var memory := NpcMemoryStore.new()
	memory.max_recent_messages = 3
	add_child_autofree(memory)
	memory.append_message(&"fixture_npc", &"player", "one")
	memory.append_message(&"fixture_npc", &"npc", "two")
	memory.append_message(&"fixture_npc", &"player", "three")
	memory.append_message(&"fixture_npc", &"npc", "four")
	memory.remember_fact(&"fixture_npc", &"favorite_weather", "Rain")

	var restored := NpcMemoryStore.new()
	restored.max_recent_messages = 3
	add_child_autofree(restored)
	restored.load_save_data(memory.to_save_data())

	var messages := restored.get_recent_messages(&"fixture_npc")
	assert_eq(messages.size(), 3)
	assert_eq(String(messages[0]["text"]), "two")
	assert_eq(String(messages[2]["text"]), "four")
	assert_eq(String(restored.get_facts(&"fixture_npc")["favorite_weather"]), "Rain")

func test_npc_memory_load_sanitizes_malformed_history_without_crashing() -> void:
	var memory := NpcMemoryStore.new()
	memory.max_recent_messages = 2
	add_child_autofree(memory)
	memory.load_save_data({
		"history": {
			"broken": "not-an-array",
			"fixture_npc": [
				42,
				{"role": "player", "text": "   ", "day": -5, "minute_of_day": -9},
				{"role": "npc", "text": " one ", "day": WorldClock.day + 999, "minute_of_day": 99999, "location_id": "retired_town"},
				{"role": "player", "text": "two", "day": 1, "minute_of_day": 12},
				{"role": "npc", "text": "three", "day": 1, "minute_of_day": 13},
			],
		},
		"facts": {
			"fixture_npc": {"favorite_weather": "Rain"},
			"broken": "not-a-dictionary",
		},
	})
	assert_true(memory.get_recent_messages(&"broken").is_empty())
	var messages := memory.get_recent_messages(&"fixture_npc")
	assert_eq(messages.size(), 2)
	assert_eq(String(messages[0].get("text", "")), "two")
	assert_eq(String(messages[1].get("text", "")), "three")
	assert_lte(int(messages[1].get("day", 999999)), maxi(WorldClock.day, 1))
	assert_true(memory.get_facts(&"broken").is_empty())
	assert_eq(String(memory.get_facts(&"fixture_npc").get("favorite_weather", "")), "Rain")

func test_npc_context_contains_stable_world_and_profile_data() -> void:
	var profile := NpcProfileData.new()
	profile.id = &"fixture_npc"
	profile.display_name = "Fixture"
	profile.role = "Fixture gardener"
	ContentFixture.use(self, [profile])

	var context := NpcContext.build_context(&"fixture_npc")

	assert_false(context.is_empty())
	assert_eq(int(context["version"]), NpcContextService.CONTEXT_VERSION)
	assert_eq(String(context["npc"]["id"]), "fixture_npc")
	assert_eq(String(context["npc"]["role"]), "Fixture gardener")
	assert_true(context["world"].has("weather"))
	assert_true(context["player"].has("vitals"))
	assert_true(context.has("memory"))
	var facts := GameModules.get_facts()
	for section: String in facts:
		assert_eq(context[section], facts[section], "what the game's modules tell about the game: %s" % section)
	assert_true(NpcContext.build_context(&"no_such_npc").is_empty(), "an unknown NPC has no context")
