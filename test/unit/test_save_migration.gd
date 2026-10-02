extends GutTest

func test_v1_save_migrates_to_current_structure() -> void:
	var old_save := {
		"version": 1,
		"clock": {"day": 3, "minute_of_day": 600},
		"inventory": {},
		"world": {},
	}
	var migrated := SaveMigration.migrate(old_save, GameSaveManager.SAVE_VERSION)

	assert_eq(int(migrated["version"]), GameSaveManager.SAVE_VERSION)
	assert_true(migrated.has("weather"))
	assert_true(migrated.has("player_state"))
	assert_true(migrated.has("relationships"))
	assert_true(migrated.has("quests"))
	assert_true(migrated.has("skills"))
	assert_true(migrated.has("npc_memory"))
	assert_true(migrated.has("fishing"))
	assert_eq(int(migrated["player_state"]["max_health"]), 100)
	assert_eq(int(migrated["player_state"]["health"]), 100)
	assert_eq(int(migrated["inventory"]["pickaxe"]["quantity"]), 1)
	assert_eq(int(migrated["inventory"]["rusty_sword"]["quantity"]), 1)
	assert_eq(int(migrated["skills"]["mining"]), 0)
	assert_eq(int(migrated["skills"]["combat"]), 0)
	assert_eq(int(migrated["shipping"]["last_day_seen"]), 3)
	assert_true((migrated["shipping"]["pending"] as Dictionary).is_empty())
	assert_true((migrated["buffs"] as Dictionary).is_empty())
	assert_eq(int(migrated["clock"]["day"]), 3)
	assert_eq(String(migrated.get("scene", "")), SaveMigration.LEGACY_DEFAULT_SCENE)
	assert_eq(String(migrated.get("location_id", "")), SaveMigration.LEGACY_DEFAULT_LOCATION_ID)
	assert_eq(String(GameSessionService.START_LOCATION_ID), SaveMigration.LEGACY_DEFAULT_LOCATION_ID)
	var start_location := ContentDB.get_location(GameSessionService.START_LOCATION_ID)
	assert_not_null(start_location)
	if start_location != null:
		assert_true(ResourceLoader.exists(start_location.scene_path))

func test_migration_sanitizes_malformed_legacy_numeric_fields() -> void:
	var malformed := {
		"version": {"bad": true},
		"clock": {"day": {"bad": true}, "minute_of_day": [600]},
		"inventory": {},
		"world": {},
		"player_state": {"max_health": {"bad": true}, "health": [99]},
	}
	var migrated := SaveMigration.migrate(malformed, GameSaveManager.SAVE_VERSION)
	assert_eq(int(migrated.get("version", 0)), GameSaveManager.SAVE_VERSION)
	assert_eq(int((migrated.get("player_state", {}) as Dictionary).get("max_health", 0)), 100)
	assert_eq(int((migrated.get("player_state", {}) as Dictionary).get("health", 0)), 100)
	assert_eq(int((migrated.get("shipping", {}) as Dictionary).get("last_day_seen", 0)), 1)
	assert_eq(String(migrated.get("location_id", "")), SaveMigration.LEGACY_DEFAULT_LOCATION_ID)

func test_v7_scene_paths_migrate_to_stable_location_ids() -> void:
	var expected := {
		"res://game/world/dev_world.tscn": "starter_town",
		"res://game/world/riverside_town.tscn": "riverside_town",
		"res://game/world/harbor_town.tscn": "harbor_town",
		"res://game/world/home_interior.tscn": "player_home",
		"res://game/world/old_mine.tscn": "old_mine",
	}
	for scene_path: String in expected.keys():
		var legacy := {
			"version": 7,
			"scene": scene_path,
			"clock": {"day": 10, "minute_of_day": 600},
			"weather": {},
			"inventory": {},
			"player_state": {},
			"world": {},
			"relationships": {},
			"npc_memory": {},
			"quests": {},
			"skills": {},
			"buffs": {},
			"shipping": {"pending": {}, "last_day_seen": 10},
			"fishing": {},
		}
		var migrated := SaveMigration.migrate(legacy, GameSaveManager.SAVE_VERSION)
		assert_eq(String(migrated.get("location_id", "")), String(expected[scene_path]))

func test_current_save_migration_is_idempotent() -> void:
	var current := {"version": GameSaveManager.SAVE_VERSION, "scene": SaveMigration.LEGACY_DEFAULT_SCENE, "location_id": "starter_town", "npc_memory": {"facts": {"mira": {"x": true}}}, "fishing": {"cast_count": 7}, "shipping": {"pending": {}, "last_day_seen": 5}, "buffs": {"hearty_worker": 9999}, "player_state": {"health": 90, "max_health": 100}}
	var migrated := SaveMigration.migrate(current, GameSaveManager.SAVE_VERSION)

	assert_eq(migrated, current)

func test_apply_snapshot_sanitizes_malformed_core_section_values_without_crashing() -> void:
	var clock_snapshot := WorldClock.to_save_data()
	var weather_snapshot := WeatherState.to_save_data()
	var inventory_snapshot := InventoryState.to_save_data()
	var player_snapshot := PlayerState.to_save_data()
	var world_snapshot := WorldState.to_save_data()
	var relationship_snapshot := RelationshipState.to_save_data()
	var memory_snapshot := NpcMemory.to_save_data()
	var quest_snapshot := QuestState.to_save_data()
	var skill_snapshot := Skills.to_save_data()
	var buff_snapshot := BuffState.to_save_data()
	var shipping_snapshot := ShippingState.to_save_data()
	var fishing_snapshot := FishingState.to_save_data()

	var malformed := {
		"version": 7,
		"scene": "",
		"clock": {"day": {"bad": true}, "minute_of_day": [480]},
		"weather": {"world_seed": {"bad": true}},
		"inventory": {"stone": {"quantity": {"bad": true}, "max_stack": [99]}},
		"player_state": {
			"max_energy": {"bad": true},
			"energy": [50],
			"max_health": {"bad": true},
			"health": [50],
			"money": {"bad": true},
			"selected_slot": {"bad": true},
			"hotbar": [],
		},
		"world": {"project:malformed:complete": {"truthy": true}},
		"relationships": {
			"points": {"mira": {"bad": true}},
			"last_talk_day": {"mira": [999]},
			"last_gift_day": {"mira": {"bad": true}},
		},
		"npc_memory": {"history": {"mira": "bad"}, "facts": {"mira": "bad"}},
		"quests": {"meet_mira": {"status": {"bad": true}, "progress": [99]}},
		"skills": {"mining": {"bad": true}, "__level:mining": [10]},
		"buffs": {"hearty_worker": {"bad": true}},
		"shipping": {
			"pending": {"turnip": {"quantity": {"bad": true}, "value": [999]}},
			"last_day_seen": {"bad": true},
		},
		"fishing": {"cast_count": {"bad": true}},
		"player": {"x": {"bad": true}, "y": [10]},
	}
	assert_true(await SaveManager.apply_snapshot(malformed))
	assert_eq(WorldClock.day, 1)
	assert_eq(WorldClock.minute_of_day, 8 * 60)
	assert_eq(WeatherState.world_seed, 93017)
	assert_eq(PlayerState.max_energy, 100)
	assert_eq(PlayerState.energy, 100)
	assert_eq(PlayerState.max_health, 100)
	assert_eq(PlayerState.health, 100)
	assert_eq(PlayerState.money, 500)
	assert_eq(PlayerState.selected_slot, 0)
	assert_eq(InventoryState.get_quantity(&"stone"), 0)
	assert_eq(RelationshipState.get_points(&"mira"), 0)
	assert_eq(Skills.get_xp(SkillManager.MINING), 0)
	assert_eq(Skills.get_level(SkillManager.MINING), 1)
	assert_false(BuffState.has_buff(&"hearty_worker"))
	assert_eq(ShippingState.get_pending_total(), 0)
	assert_eq(FishingState.cast_count, 0)
	assert_false(WorldState.get_bool(&"project:malformed:complete"))
	assert_false(QuestState.is_active(&"meet_mira"))
	assert_true(NpcMemory.get_recent_messages(&"mira").is_empty())
	assert_true(NpcMemory.get_facts(&"mira").is_empty())

	WeatherState.load_save_data(weather_snapshot)
	ShippingState.load_save_data(shipping_snapshot)
	WorldClock.load_save_data(clock_snapshot)
	BuffState.load_save_data(buff_snapshot)
	InventoryState.load_save_data(inventory_snapshot)
	PlayerState.load_save_data(player_snapshot)
	WorldState.load_save_data(world_snapshot)
	RelationshipState.load_save_data(relationship_snapshot)
	NpcMemory.load_save_data(memory_snapshot)
	QuestState.load_save_data(quest_snapshot)
	Skills.load_save_data(skill_snapshot)
	FishingState.load_save_data(fishing_snapshot)
	EventState.refresh(WorldClock.day, WorldClock.minute_of_day)

func test_apply_snapshot_does_not_leak_current_session_into_missing_legacy_sections() -> void:
	var clock_snapshot := WorldClock.to_save_data()
	var weather_snapshot := WeatherState.to_save_data()
	var inventory_snapshot := InventoryState.to_save_data()
	var player_snapshot := PlayerState.to_save_data()
	var world_snapshot := WorldState.to_save_data()
	var relationship_snapshot := RelationshipState.to_save_data()
	var memory_snapshot := NpcMemory.to_save_data()
	var quest_snapshot := QuestState.to_save_data()
	var skill_snapshot := Skills.to_save_data()
	var buff_snapshot := BuffState.to_save_data()
	var shipping_snapshot := ShippingState.to_save_data()
	var fishing_snapshot := FishingState.to_save_data()

	PlayerState.money = 9999
	PlayerState.set_hotbar_item(0, &"iridium_pickaxe")
	Skills.add_xp(SkillManager.MINING, 5000)
	QuestState.load_save_data({"reach_mine_bottom": {"status": QuestManager.Status.ACTIVE, "progress": 119}})
	InventoryState.add_item_by_id(&"iridium_bar", 3)

	var legacy_like := {
		"version": 7,
		"scene": "",
		"clock": {"day": 3, "minute_of_day": 600},
		"weather": {},
		"inventory": {},
		"player_state": {},
		"world": {},
		"relationships": {},
		"npc_memory": {},
		"quests": {},
		"skills": {},
		"buffs": {},
		"shipping": {"pending": {}, "last_day_seen": 3},
		"fishing": {},
	}
	assert_true(await SaveManager.apply_snapshot(legacy_like))
	assert_eq(PlayerState.money, 500)
	assert_eq(PlayerState.hotbar[0], &"hoe")
	assert_eq(Skills.get_xp(SkillManager.MINING), 0)
	assert_true(QuestState.is_active(&"meet_mira"))
	assert_true(QuestState.is_active(&"gather_berries"))
	assert_false(QuestState.is_active(&"reach_mine_bottom"))
	assert_eq(InventoryState.get_quantity(&"iridium_bar"), 0)

	WeatherState.load_save_data(weather_snapshot)
	ShippingState.load_save_data(shipping_snapshot)
	WorldClock.load_save_data(clock_snapshot)
	BuffState.load_save_data(buff_snapshot)
	InventoryState.load_save_data(inventory_snapshot)
	PlayerState.load_save_data(player_snapshot)
	WorldState.load_save_data(world_snapshot)
	RelationshipState.load_save_data(relationship_snapshot)
	NpcMemory.load_save_data(memory_snapshot)
	QuestState.load_save_data(quest_snapshot)
	Skills.load_save_data(skill_snapshot)
	FishingState.load_save_data(fishing_snapshot)
	EventState.refresh(WorldClock.day, WorldClock.minute_of_day)
