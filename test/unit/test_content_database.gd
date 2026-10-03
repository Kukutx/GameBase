extends GutTest

func test_manifest_indexes_all_core_content() -> void:
	var errors := ContentDB.rebuild()
	assert_eq(errors.size(), 0)
	assert_not_null(ContentDB.get_item(&"berry"))
	assert_not_null(ContentDB.get_crop(&"turnip"))
	assert_not_null(ContentDB.get_npc(&"mira"))
	assert_not_null(ContentDB.get_npc(&"rowan"))
	assert_not_null(ContentDB.get_npc(&"neri"))
	assert_not_null(ContentDB.get_farm_animal(&"chicken"))
	assert_not_null(ContentDB.get_farm_animal(&"cow"))
	assert_not_null(ContentDB.get_fish(&"river_trout"))
	assert_not_null(ContentDB.get_fish(&"sardine"))
	assert_not_null(ContentDB.get_mining_node(&"stone_rock"))
	assert_not_null(ContentDB.get_enemy(&"green_slime"))
	assert_not_null(ContentDB.get_quest(&"first_harvest"))
	assert_not_null(ContentDB.get_shop(&"general_store"))
	assert_not_null(ContentDB.get_recipe(&"field_snack"))
	assert_not_null(ContentDB.get_location(&"starter_town"))
	assert_not_null(ContentDB.get_location(&"riverside_town"))
	assert_not_null(ContentDB.get_location(&"harbor_town"))
	assert_not_null(ContentDB.get_audio_cue(&"sfx_pickup"))
	assert_not_null(ContentDB.get_audio_cue(&"music_old_mine"))

func test_unknown_ids_return_null() -> void:
	assert_null(ContentDB.get_item(&"does_not_exist"))
	assert_null(ContentDB.get_location(&"does_not_exist"))
	assert_null(ContentDB.get_audio_cue(&"does_not_exist"))

func test_locations_have_packed_scenes_and_unique_default_spawn_points() -> void:
	var locations := ContentDB.get_all_locations()
	assert_eq(locations.size(), 5)
	for location: WorldLocationData in locations:
		assert_not_null(location)
		if location == null:
			continue
		var packed := load(location.scene_path) as PackedScene
		assert_not_null(packed, "%s does not resolve to a PackedScene" % location.id)
		if packed == null:
			continue
		assert_eq(int(ContentDB.call("_get_scene_group_count", packed, &"player")), 1, "%s must contain exactly one player" % location.id)
		var counts := ContentDB.call("_get_scene_spawn_counts", packed) as Dictionary
		assert_true(counts.has(String(location.default_spawn_id)), "%s is missing default spawn %s" % [location.id, location.default_spawn_id])
		for raw_spawn_id: Variant in counts.keys():
			var spawn_id := String(raw_spawn_id)
			assert_false(spawn_id.is_empty(), "%s has an empty spawn id" % location.id)
			assert_eq(int(counts[raw_spawn_id]), 1, "%s has duplicate spawn id %s" % [location.id, spawn_id])
		for portal: Dictionary in ContentDB.call("_get_scene_portal_records", packed) as Array[Dictionary]:
			assert_false(String(portal.get("target_location_id", "")).is_empty(), "%s has a portal without stable Location ID" % location.id)
			assert_true(String(portal.get("target_scene", "")).is_empty(), "%s has a portal using a direct scene path" % location.id)

func test_location_persistent_state_keys_are_nonempty_when_required_and_globally_unique() -> void:
	var seen: Dictionary = {}
	for location: WorldLocationData in ContentDB.get_all_locations():
		var packed := load(location.scene_path) as PackedScene
		assert_not_null(packed)
		if packed == null:
			continue
		for record: Dictionary in ContentDB.call("_get_scene_persistent_state_records", packed) as Array[Dictionary]:
			var state_key := String(record.get("key", ""))
			if bool(record.get("required", false)):
				assert_false(state_key.is_empty(), "%s/%s is missing a required persistent id" % [location.id, record.get("node_name", "Node")])
			if state_key.is_empty():
				continue
			assert_false(seen.has(state_key), "Persistent state key %s is duplicated" % state_key)
			seen[state_key] = "%s/%s" % [location.id, record.get("node_name", "Node")]
	assert_gt(seen.size(), 0)

func test_location_scene_reference_validator_rejects_broken_runtime_links() -> void:
	var location := ContentDB.get_location(&"starter_town")
	assert_not_null(location)
	if location == null:
		return
	var root := Node2D.new()
	var trough := AnimalFeedTrough.new()
	trough.name = "BadTrough"
	trough.housing_id = &"missing_housing"
	trough.feed_item_id = &"berry"
	root.add_child(trough)
	var field := FarmField.new()
	field.name = "BadField"
	field.field_id = &"bad_field"
	field.location_id = &"harbor_town"
	root.add_child(field)
	var spawner := ForageSpawner.new()
	spawner.name = "BadSpawner"
	spawner.spawner_id = &"bad_spawner"
	spawner.location_id = &"harbor_town"
	root.add_child(spawner)
	var spot := FishingSpot.new()
	spot.name = "BadFishing"
	spot.location_id = &"harbor_town"
	spot.required_rod_id = &"hoe"
	root.add_child(spot)
	var board := TownProjectBoard.new()
	board.name = "BadBoard"
	board.location_id = &"harbor_town"
	root.add_child(board)
	var booth := CalendarEventBooth.new()
	booth.name = "BadBooth"
	booth.event_id = &"summer_river_fair"
	root.add_child(booth)
	var station := ProcessingStation.new()
	station.name = "BadStation"
	station.station_id = &"bad_station"
	station.recipe_ids = [&"smelt_copper_bar", &"smelt_copper_bar", &"missing_recipe"]
	root.add_child(station)
	var stand := ShopStand.new()
	stand.name = "BadShop"
	stand.shop = ShopData.new()
	stand.shop.id = &"unregistered_shop"
	root.add_child(stand)
	var errors := PackedStringArray()
	ContentDB.call("_validate_location_node_references", root, location, {}, errors)
	root.free()
	var joined := "\n".join(errors)
	assert_string_contains(joined, "feed trough 'BadTrough' references unknown housing 'missing_housing'")
	assert_string_contains(joined, "feed trough 'BadTrough' references invalid feed item 'berry'")
	assert_string_contains(joined, "farm field 'BadField' references different location 'harbor_town'")
	assert_string_contains(joined, "forage spawner 'BadSpawner' references different location 'harbor_town'")
	assert_string_contains(joined, "fishing spot 'BadFishing' references different location 'harbor_town'")
	assert_string_contains(joined, "fishing spot 'BadFishing' references invalid fishing rod 'hoe'")
	assert_string_contains(joined, "town project board 'BadBoard' references different location 'harbor_town'")
	assert_string_contains(joined, "event booth 'BadBooth' references event 'summer_river_fair' from location 'riverside_town'")
	assert_string_contains(joined, "processing station 'BadStation' repeats recipe 'smelt_copper_bar'")
	assert_string_contains(joined, "processing station 'BadStation' references unknown recipe 'missing_recipe'")
	assert_string_contains(joined, "shop stand 'BadShop' references an unregistered shop")

func test_reference_validator_rejects_invalid_deferred_reward_and_condition_data() -> void:
	var db := GameContentDatabase.new()
	autofree(db)
	var berry := ContentDB.get_item(&"berry")
	assert_not_null(berry)
	if berry == null:
		return
	var source_tool := ItemData.new()
	source_tool.id = &"source_tool"
	source_tool.kind = ItemData.Kind.TOOL
	source_tool.tool_action = &"pickaxe"
	source_tool.tool_power = 2
	source_tool.max_stack = 1
	var result_tool := ItemData.new()
	result_tool.id = &"result_tool"
	result_tool.kind = ItemData.Kind.TOOL
	result_tool.tool_action = &"attack"
	result_tool.tool_power = 2
	result_tool.max_stack = 1
	var bad_tool := ItemData.new()
	bad_tool.id = &"bad_tool"
	bad_tool.kind = ItemData.Kind.TOOL
	bad_tool.tool_action = &"typo_action"
	bad_tool.max_stack = 2
	var bad_material := ItemData.new()
	bad_material.id = &"bad_material"
	bad_material.kind = ItemData.Kind.MATERIAL
	bad_material.crop_id = &"bad_crop"
	db.set("_items", {"berry": berry, "source_tool": source_tool, "result_tool": result_tool, "bad_tool": bad_tool, "bad_material": bad_material})
	var locations: Dictionary = {}
	for location: WorldLocationData in ContentDB.get_all_locations():
		locations[String(location.id)] = location
	db.set("_locations", locations)

	var bad_mail := MailData.new()
	bad_mail.id = &"bad_mail"
	bad_mail.subject = "Bad"
	bad_mail.body = "Bad"
	bad_mail.required_hearts = 2
	bad_mail.reward_items = {"berry": 0}
	db.set("_mail", {"bad_mail": bad_mail})

	var bad_project := TownProjectData.new()
	bad_project.id = &"bad_project"
	bad_project.location_id = &"starter_town"
	bad_project.requirements = {"berry": 1}
	bad_project.reward_items = {"berry": -1}
	db.set("_town_projects", {"bad_project": bad_project})

	var bad_milestone := CollectionMilestoneData.new()
	bad_milestone.id = &"bad_milestone"
	bad_milestone.category = &"retired_category"
	bad_milestone.reward_items = {"berry": 0}
	db.set("_collection_milestones", {"bad_milestone": bad_milestone})

	var bad_crop := CropData.new()
	bad_crop.id = &"bad_crop"
	bad_crop.harvest_item_id = &"berry"
	db.set("_crops", {"bad_crop": bad_crop})

	var bad_buff := FoodBuffData.new()
	bad_buff.id = &"bad_buff"
	bad_buff.modifiers = {"typo_speed": 1.2, "tool_energy": 0.0}
	db.set("_food_buffs", {"bad_buff": bad_buff})

	var bad_fish := FishData.new()
	bad_fish.id = &"bad_fish"
	bad_fish.item_id = &"berry"
	bad_fish.start_minute = 360
	bad_fish.end_minute = 360
	db.set("_fish", {"bad_fish": bad_fish})

	var bad_animal := FarmAnimalData.new()
	bad_animal.id = &"bad_animal"
	bad_animal.feed_item_id = &""
	bad_animal.product_item_id = &"berry"
	db.set("_animals", {"bad_animal": bad_animal})

	var bad_mining := MiningNodeData.new()
	bad_mining.id = &"bad_mining"
	bad_mining.drop_item_id = &"berry"
	db.set("_mining_nodes", {"bad_mining": bad_mining})

	var bad_upgrade := ToolUpgradeData.new()
	bad_upgrade.id = &"bad_upgrade"
	bad_upgrade.source_item_id = &"source_tool"
	bad_upgrade.result_item_id = &"result_tool"
	db.set("_tool_upgrades", {"bad_upgrade": bad_upgrade})

	var errors := PackedStringArray()
	db.call("_validate_references", errors)
	var joined := "\n".join(errors)
	assert_string_contains(joined, "mail 'bad_mail' requires hearts but has no sender npc")
	assert_string_contains(joined, "mail 'bad_mail' has invalid reward quantity for 'berry'")
	assert_string_contains(joined, "town project 'bad_project' has invalid reward quantity for 'berry'")
	assert_string_contains(joined, "collection milestone 'bad_milestone' references unknown category 'retired_category'")
	assert_string_contains(joined, "collection milestone 'bad_milestone' has invalid reward quantity for 'berry'")
	assert_string_contains(joined, "tool item 'bad_tool' has invalid tool action 'typo_action'")
	assert_string_contains(joined, "tool item 'bad_tool' must have max_stack 1")
	assert_string_contains(joined, "non-seed item 'bad_material' unexpectedly references crop 'bad_crop'")
	assert_string_contains(joined, "crop 'bad_crop' harvest item 'berry' is not a CROP item")
	assert_string_contains(joined, "food buff 'bad_buff' references unsupported stat 'typo_speed'")
	assert_string_contains(joined, "food buff 'bad_buff' has non-positive or non-numeric multiplier for 'tool_energy'")
	assert_string_contains(joined, "fish 'bad_fish' item 'berry' lacks fish tag")
	assert_string_contains(joined, "fish 'bad_fish' has an empty time window")
	assert_string_contains(joined, "farm animal 'bad_animal' product 'berry' lacks animal_product tag")
	assert_string_contains(joined, "mining node 'bad_mining' drop 'berry' lacks mining tag")
	assert_string_contains(joined, "tool upgrade 'bad_upgrade' changes tool action from 'pickaxe' to 'attack'")
	assert_string_contains(joined, "tool upgrade 'bad_upgrade' result power 2 does not exceed source power 2")

func test_reference_validator_reports_malformed_numeric_and_unreachable_schedule_values_without_crashing() -> void:
	var db := GameContentDatabase.new()
	autofree(db)
	var berry := ContentDB.get_item(&"berry")
	assert_not_null(berry)
	if berry == null:
		return
	db.set("_items", {"berry": berry})
	var locations: Dictionary = {}
	for location: WorldLocationData in ContentDB.get_all_locations():
		locations[String(location.id)] = location
	db.set("_locations", locations)

	var schedule := NpcScheduleEntry.new()
	schedule.location_id = &"starter_town"
	schedule.days_of_week = PackedInt32Array([8])
	schedule.seasons = PackedStringArray(["Monsoon"])
	var npc := NpcProfileData.new()
	npc.id = &"bad_npc"
	npc.home_location_id = &"starter_town"
	npc.default_location_id = &"starter_town"
	npc.dialogue_titles_by_hearts = {"oops": "bad", 99: "too_high", 2: {"bad": true}}
	npc.schedule_entries = [schedule]
	assert_eq(npc.get_dialogue_title("fallback", 10), "fallback")
	db.set("_npcs", {"bad_npc": npc})

	var heart := HeartEventData.new()
	heart.id = &"bad_heart"
	heart.npc_id = &"bad_npc"
	heart.dialogue_title = "bad"
	heart.location_id = &"starter_town"
	heart.required_hearts = 99
	heart.start_minute = 600
	heart.end_minute = 600
	db.set("_heart_events", {"bad_heart": heart})

	var shop := ShopData.new()
	shop.id = &"bad_shop"
	shop.stock = {"berry": "not-a-price"}
	shop.seasonal_stock = {"Spring": {"berry": {"bad": true}}}
	db.set("_shops", {"bad_shop": shop})

	var recipe := RecipeData.new()
	recipe.id = &"bad_recipe"
	recipe.display_name = "Bad Recipe"
	recipe.ingredients = {"berry": {"bad": true}}
	recipe.output_item_id = &"berry"
	recipe.output_quantity = 0
	recipe.required_skill = SkillManager.FARMING
	recipe.required_level = 99
	db.set("_recipes", {"bad_recipe": recipe})

	var quest := QuestData.new()
	quest.id = &"bad_quest"
	quest.title = ""
	quest.objective_type = QuestData.ObjectiveType.COLLECT
	quest.target_id = &"berry"
	quest.required_amount = 0
	quest.reward_money = -1
	quest.reward_items = {"berry": {"bad": true}}
	quest.entry_point = true
	db.set("_quests", {"bad_quest": quest})

	var event := CalendarEventData.new()
	event.id = &"bad_event"
	event.location_id = &"starter_town"
	event.day_of_season = 99
	event.days_of_week = PackedInt32Array([7])
	event.start_minute = 600
	event.end_minute = 600
	event.reward_money = -1
	event.reward_items = {"berry": {"bad": true}}
	db.set("_calendar_events", {"bad_event": event})

	var errors := PackedStringArray()
	db.call("_validate_references", errors)
	var joined := "\n".join(errors)
	assert_string_contains(joined, "npc 'bad_npc' dialogue threshold 'oops' is not an integer")
	assert_string_contains(joined, "npc 'bad_npc' dialogue threshold 99 is outside heart range")
	assert_string_contains(joined, "npc 'bad_npc' dialogue threshold 2 has an invalid title")
	assert_string_contains(joined, "npc 'bad_npc' schedule has invalid weekday 8")
	assert_string_contains(joined, "npc 'bad_npc' schedule has unknown season 'Monsoon'")
	assert_string_contains(joined, "heart event 'bad_heart' has invalid heart requirement 99")
	assert_string_contains(joined, "heart event 'bad_heart' has an invalid time window")
	assert_string_contains(joined, "shop 'bad_shop' has invalid price for 'berry'")
	assert_string_contains(joined, "shop 'bad_shop' has invalid seasonal price for 'berry'")
	assert_string_contains(joined, "recipe 'bad_recipe' has invalid ingredient quantity for 'berry'")
	assert_string_contains(joined, "recipe 'bad_recipe' has invalid output quantity 0")
	assert_string_contains(joined, "recipe 'bad_recipe' has invalid required level 99")
	assert_string_contains(joined, "quest 'bad_quest' has an empty title")
	assert_string_contains(joined, "quest 'bad_quest' has invalid required amount 0")
	assert_string_contains(joined, "quest 'bad_quest' has invalid reward quantity for 'berry'")
	assert_string_contains(joined, "calendar event 'bad_event' has invalid day-of-season 99")
	assert_string_contains(joined, "calendar event 'bad_event' has invalid weekday 7")
	assert_string_contains(joined, "calendar event 'bad_event' has invalid reward quantity for 'berry'")

func test_quest_entry_points_cover_the_entire_registered_graph() -> void:
	var quests := ContentDB.get_all_quests()
	assert_eq(quests.size(), 18)
	var entry_ids: Array[String] = []
	var auto_ids: Array[String] = []
	for quest: QuestData in quests:
		if quest.entry_point:
			entry_ids.append(String(quest.id))
		if quest.auto_start:
			auto_ids.append(String(quest.id))
	entry_ids.sort()
	auto_ids.sort()
	assert_eq(entry_ids, ["gather_berries", "meet_mira"])
	assert_eq(auto_ids, ["gather_berries", "meet_mira"])

func test_quest_reachability_validator_reports_orphans_and_invalid_auto_start() -> void:
	var entry := QuestData.new()
	entry.id = &"entry"
	entry.entry_point = true
	entry.auto_start = true
	var chained := QuestData.new()
	chained.id = &"chained"
	var orphan := QuestData.new()
	orphan.id = &"orphan"
	var messages: Array = ContentDB.call("_collect_quest_reachability_errors", {"entry": entry, "chained": chained, "orphan": orphan}, {"entry": ["chained"], "chained": [], "orphan": []})
	assert_eq(messages.size(), 1)
	assert_string_contains(String(messages[0]), "quest 'orphan' is unreachable")

	var invalid_auto := QuestData.new()
	invalid_auto.id = &"invalid_auto"
	invalid_auto.auto_start = true
	messages = ContentDB.call("_collect_quest_reachability_errors", {"invalid_auto": invalid_auto}, {"invalid_auto": []})
	assert_eq(messages.size(), 2)
	assert_string_contains(String(messages[0]), "auto-starts but is not marked as an entry point")
	assert_string_contains(String(messages[1]), "quest graph has no entry points")

func test_dependency_cycle_detector_accepts_acyclic_graph_and_ignores_unknown_edges() -> void:
	var graph := {
		"a": ["b"],
		"b": ["c"],
		"c": ["missing_external_reference"],
	}
	var messages: Array = ContentDB.call("_collect_dependency_cycle_errors", graph, "test graph")
	assert_eq(messages.size(), 0)

func test_dependency_cycle_detector_reports_self_two_node_and_three_node_cycles() -> void:
	var self_cycle: Array = ContentDB.call("_collect_dependency_cycle_errors", {"a": ["a"]}, "quest")
	assert_eq(self_cycle.size(), 1)
	assert_string_contains(String(self_cycle[0]), "a -> a")

	var two_cycle: Array = ContentDB.call("_collect_dependency_cycle_errors", {"a": ["b"], "b": ["a"]}, "town project")
	assert_eq(two_cycle.size(), 1)
	assert_string_contains(String(two_cycle[0]), "town project dependency cycle")
	assert_string_contains(String(two_cycle[0]), "a -> b -> a")

	var three_cycle: Array = ContentDB.call("_collect_dependency_cycle_errors", {"a": ["b"], "b": ["c"], "c": ["a"]}, "farm expansion")
	assert_eq(three_cycle.size(), 1)
	assert_string_contains(String(three_cycle[0]), "farm expansion dependency cycle")
	assert_string_contains(String(three_cycle[0]), "a -> b -> c -> a")

func test_expansion_progression_validator_rejects_duplicate_cross_housing_and_non_increasing_tiers() -> void:
	var big := FarmExpansionData.new()
	big.id = &"big"
	big.housing_id = &"coop"
	big.capacity_after = 8
	var deluxe := FarmExpansionData.new()
	deluxe.id = &"deluxe"
	deluxe.housing_id = &"coop"
	deluxe.capacity_after = 12
	deluxe.prerequisites = [&"big"]
	var valid_messages: Array = ContentDB.call("_collect_expansion_progression_errors", {"big": big, "deluxe": deluxe})
	assert_eq(valid_messages.size(), 0)

	var duplicate := FarmExpansionData.new()
	duplicate.id = &"duplicate"
	duplicate.housing_id = &"coop"
	duplicate.capacity_after = 8
	var duplicate_messages: Array = ContentDB.call("_collect_expansion_progression_errors", {"big": big, "duplicate": duplicate})
	assert_eq(duplicate_messages.size(), 1)
	assert_string_contains(String(duplicate_messages[0]), "share housing 'coop' capacity 8")

	var wrong_housing := FarmExpansionData.new()
	wrong_housing.id = &"wrong_housing"
	wrong_housing.housing_id = &"barn"
	wrong_housing.capacity_after = 12
	wrong_housing.prerequisites = [&"big"]
	var housing_messages: Array = ContentDB.call("_collect_expansion_progression_errors", {"big": big, "wrong_housing": wrong_housing})
	assert_eq(housing_messages.size(), 1)
	assert_string_contains(String(housing_messages[0]), "different housing")

	var backwards := FarmExpansionData.new()
	backwards.id = &"backwards"
	backwards.housing_id = &"coop"
	backwards.capacity_after = 6
	backwards.prerequisites = [&"big"]
	var backwards_messages: Array = ContentDB.call("_collect_expansion_progression_errors", {"big": big, "backwards": backwards})
	assert_eq(backwards_messages.size(), 1)
	assert_string_contains(String(backwards_messages[0]), "does not exceed prerequisite")
