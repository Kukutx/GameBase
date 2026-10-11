extends GutTest

func test_npc_memory_is_bounded_and_round_trips() -> void:
	var memory := NpcMemoryStore.new()
	memory.max_recent_messages = 3
	add_child_autofree(memory)
	memory.append_message(&"mira", &"player", "one")
	memory.append_message(&"mira", &"npc", "two")
	memory.append_message(&"mira", &"player", "three")
	memory.append_message(&"mira", &"npc", "four")
	memory.remember_fact(&"mira", &"favorite_weather", "Rain")

	var restored := NpcMemoryStore.new()
	restored.max_recent_messages = 3
	add_child_autofree(restored)
	restored.load_save_data(memory.to_save_data())

	var messages := restored.get_recent_messages(&"mira")
	assert_eq(messages.size(), 3)
	assert_eq(String(messages[0]["text"]), "two")
	assert_eq(String(messages[2]["text"]), "four")
	assert_eq(String(restored.get_facts(&"mira")["favorite_weather"]), "Rain")

func test_npc_memory_load_sanitizes_malformed_history_without_crashing() -> void:
	var memory := NpcMemoryStore.new()
	memory.max_recent_messages = 2
	add_child_autofree(memory)
	memory.load_save_data({
		"history": {
			"broken": "not-an-array",
			"mira": [
				42,
				{"role": "player", "text": "   ", "day": -5, "minute_of_day": -9},
				{"role": "npc", "text": " one ", "day": WorldClock.day + 999, "minute_of_day": 99999, "location_id": "retired_town"},
				{"role": "player", "text": "two", "day": 1, "minute_of_day": 12},
				{"role": "npc", "text": "three", "day": 1, "minute_of_day": 13},
			],
		},
		"facts": {
			"mira": {"favorite_weather": "Rain"},
			"broken": "not-a-dictionary",
		},
	})
	assert_true(memory.get_recent_messages(&"broken").is_empty())
	var messages := memory.get_recent_messages(&"mira")
	assert_eq(messages.size(), 2)
	assert_eq(String(messages[0].get("text", "")), "two")
	assert_eq(String(messages[1].get("text", "")), "three")
	assert_lte(int(messages[1].get("day", 999999)), maxi(WorldClock.day, 1))
	assert_true(memory.get_facts(&"broken").is_empty())
	assert_eq(String(memory.get_facts(&"mira").get("favorite_weather", "")), "Rain")

func test_npc_context_contains_stable_world_and_profile_data() -> void:
	var context := NpcContext.build_context(&"mira")

	assert_false(context.is_empty())
	assert_eq(int(context["version"]), NpcContextService.CONTEXT_VERSION)
	assert_eq(String(context["npc"]["id"]), "mira")
	assert_eq(String(context["npc"]["role"]), "Village gardener")
	assert_true(context["world"].has("weather"))
	assert_true(context["world"].has("active_events"))
	assert_true(context["player"].has("inventory"))
	assert_true(context.has("memory"))
