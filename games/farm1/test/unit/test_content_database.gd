extends GutTest

func test_manifest_indexes_all_core_content() -> void:
	var errors := ContentDB.rebuild()
	assert_eq(errors.size(), 0)
	assert_not_null(ItemData.find(&"berry"))
	assert_not_null(CropData.find(&"turnip"))
	assert_not_null(NpcProfileData.find(&"mira"))
	assert_not_null(NpcProfileData.find(&"rowan"))
	assert_not_null(NpcProfileData.find(&"neri"))
	assert_not_null(FarmAnimalData.find(&"chicken"))
	assert_not_null(FarmAnimalData.find(&"cow"))
	assert_not_null(FishData.find(&"river_trout"))
	assert_not_null(FishData.find(&"sardine"))
	assert_not_null(MiningNodeData.find(&"stone_rock"))
	assert_not_null(EnemyData.find(&"green_slime"))
	assert_not_null(QuestData.find(&"first_harvest"))
	assert_not_null(ShopData.find(&"general_store"))
	assert_not_null(RecipeData.find(&"field_snack"))
	assert_not_null(WorldLocationData.find(&"starter_town"))
	assert_not_null(WorldLocationData.find(&"riverside_town"))
	assert_not_null(WorldLocationData.find(&"harbor_town"))
	assert_not_null(AudioCueData.find(&"sfx_pickup"))
	assert_not_null(AudioCueData.find(&"music_old_mine"))

func test_unknown_ids_return_null() -> void:
	assert_null(ItemData.find(&"does_not_exist"))
	assert_null(WorldLocationData.find(&"does_not_exist"))
	assert_null(AudioCueData.find(&"does_not_exist"))

func test_locations_have_packed_scenes_and_unique_default_spawn_points() -> void:
	var locations := WorldLocationData.find_all()
	assert_eq(locations.size(), 5)
	for location: WorldLocationData in locations:
		assert_not_null(location)
		if location == null:
			continue
		var packed := load(location.scene_path) as PackedScene
		assert_not_null(packed, "%s does not resolve to a PackedScene" % location.id)
		if packed == null:
			continue
		var root := packed.instantiate()
		assert_eq(int(ContentDB.call("_count_group_nodes", root, &"player")), 1, "%s must contain exactly one player" % location.id)
		var counts: Dictionary = {}
		ContentDB.call("_collect_spawn_counts", root, counts)
		assert_true(counts.has(String(location.default_spawn_id)), "%s is missing default spawn %s" % [location.id, location.default_spawn_id])
		for raw_spawn_id: Variant in counts.keys():
			var spawn_id := String(raw_spawn_id)
			assert_false(spawn_id.is_empty(), "%s has an empty spawn id" % location.id)
			assert_eq(int(counts[raw_spawn_id]), 1, "%s has duplicate spawn id %s" % [location.id, spawn_id])
		var portals: Array[ScenePortal] = []
		ContentDB.call("_collect_portals", root, portals)
		for portal: ScenePortal in portals:
			assert_ne(portal.target_location_id, &"", "%s has a portal without stable Location ID" % location.id)
		root.free()

func test_location_persistent_state_keys_are_globally_unique() -> void:
	var seen: Dictionary = {}
	for location: WorldLocationData in WorldLocationData.find_all():
		var root := (load(location.scene_path) as PackedScene).instantiate()
		for node: Node in [root] + root.find_children("*", "", true, false):
			if not node.has_method(&"get_persistent_keys"):
				continue
			for key: String in node.call(&"get_persistent_keys"):
				assert_false(seen.has(key), "Persistent state key %s is duplicated" % key)
				seen[key] = "%s/%s" % [location.id, node.name]
		root.free()
	assert_gt(seen.size(), 0)

func test_scene_nodes_report_broken_links() -> void:
	var location := WorldLocationData.find(&"starter_town")
	var root := Node2D.new()
	var trough := AnimalFeedTrough.new()
	trough.name = "BadTrough"
	trough.housing_id = &"missing_housing"
	root.add_child(trough)
	var housing := AnimalHousing.new()
	housing.name = "BadHousing"
	housing.housing_id = &"bad_housing"
	housing.location_id = location.id
	root.add_child(housing)
	var mine := MineFloorController.new()
	mine.name = "BadMine"
	mine.floor_spawn_id = &"missing_spawn"
	root.add_child(mine)
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
	station.recipe_ids = [&"smelt_copper_bar", &"smelt_copper_bar", &"missing_recipe"]
	root.add_child(station)
	var stand := ShopStand.new()
	stand.name = "BadShop"
	stand.shop = ShopData.new()
	stand.shop.id = &"unregistered_shop"
	root.add_child(stand)
	var joined := "\n".join(ContentDB.find_scene_problems(root, location))
	var placed := "\n".join(ContentDB.find_scene_problems(station, null))
	root.free()
	assert_string_contains(joined, "feed trough 'BadTrough' references unknown housing 'missing_housing'")
	assert_string_contains(joined, "housing 'bad_housing' needs a display name and a housing type")
	assert_string_contains(joined, "mine 'BadMine' has no entrance spawn")
	assert_string_contains(joined, "mine 'BadMine' names spawn 'missing_spawn', which its scene does not have")
	assert_string_contains(joined, "farm field 'BadField' references different location 'harbor_town'")
	assert_string_contains(joined, "forage spawner 'BadSpawner' references different location 'harbor_town'")
	assert_string_contains(joined, "fishing spot 'BadFishing' references different location 'harbor_town'")
	assert_string_contains(joined, "town project board 'BadBoard' references different location 'harbor_town'")
	assert_string_contains(joined, "event booth 'BadBooth' references event 'summer_river_fair' from location 'riverside_town'")
	assert_string_contains(joined, "processing station 'BadStation' has no station id")
	assert_string_contains(joined, "processing station 'BadStation' repeats recipe 'smelt_copper_bar'")
	assert_string_contains(joined, "processing station 'BadStation' references unknown recipe 'missing_recipe'")
	assert_string_contains(joined, "shop stand 'BadShop' references an unregistered shop")
	# A station placed at runtime gets its id from its record.
	assert_false(placed.contains("has no station id"))
	assert_string_contains(placed, "references unknown recipe 'missing_recipe'")

func test_entries_report_invalid_rewards_tools_and_tags() -> void:
	var source_tool := ItemData.new()
	source_tool.id = &"source_tool"
	source_tool.kind = ItemData.Kind.TOOL
	source_tool.tool_action = ItemData.ACTION_MINE
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
	bad_material.crop_id = &"bad_crop"
	var bad_seed := ItemData.new()
	bad_seed.id = &"bad_seed"
	bad_seed.kind = ItemData.Kind.SEED
	bad_seed.crop_id = &"missing_crop"
	var bad_mail := MailData.new()
	bad_mail.id = &"bad_mail"
	bad_mail.subject = "Bad"
	bad_mail.body = "Bad"
	bad_mail.required_hearts = 2
	bad_mail.reward_items = {"berry": 0}
	var bad_project := TownProjectData.new()
	bad_project.id = &"bad_project"
	bad_project.location_id = &"starter_town"
	bad_project.requirements = {"berry": 1}
	bad_project.reward_items = {"berry": -1}
	var bad_milestone := CollectionMilestoneData.new()
	bad_milestone.id = &"bad_milestone"
	bad_milestone.category = &"retired_category"
	bad_milestone.reward_items = {"berry": 0}
	var bad_crop := CropData.new()
	bad_crop.id = &"bad_crop"
	bad_crop.harvest_item_id = &"berry"
	var bad_buff := FoodBuffData.new()
	bad_buff.id = &"bad_buff"
	bad_buff.multipliers = {&"typo_speed": 1.2, &"tool_energy": 0.0}
	var bad_fish := FishData.new()
	bad_fish.id = &"bad_fish"
	bad_fish.item_id = &"berry"
	bad_fish.start_minute = 360
	bad_fish.end_minute = 360
	var bad_animal := FarmAnimalData.new()
	bad_animal.id = &"bad_animal"
	bad_animal.feed_item_id = &""
	bad_animal.product_item_id = &"berry"
	var bad_mining := MiningNodeData.new()
	bad_mining.id = &"bad_mining"
	bad_mining.drop_item_id = &"berry"
	var bad_upgrade := ToolUpgradeData.new()
	bad_upgrade.id = &"bad_upgrade"
	bad_upgrade.source_item_id = &"source_tool"
	bad_upgrade.result_item_id = &"result_tool"
	var entries: Array = [source_tool, result_tool, bad_tool, bad_material, bad_seed, bad_mail, bad_project,
			bad_milestone, bad_crop, bad_buff, bad_fish, bad_animal, bad_mining, bad_upgrade]
	var registry := _registry_with(entries)
	var joined := _problems_of(registry, entries) + "\n" + "\n".join(CropData.find_seed_problems(registry))
	assert_string_contains(joined, "mail 'bad_mail' requires hearts but has no sender npc")
	assert_string_contains(joined, "mail 'bad_mail' has invalid reward quantity for 'berry'")
	assert_string_contains(joined, "town project 'bad_project' has invalid reward quantity for 'berry'")
	assert_string_contains(joined, "collection milestone 'bad_milestone' references unknown category 'retired_category'")
	assert_string_contains(joined, "collection milestone 'bad_milestone' has invalid reward quantity for 'berry'")
	assert_string_contains(joined, "item 'bad_tool' is a tool with action 'typo_action', which no installed module or the game handles")
	assert_string_contains(joined, "item 'bad_tool' is a tool and must have max_stack 1")
	assert_false(joined.contains("item 'result_tool' is a tool with action"), "the game registers its attack action")
	assert_string_contains(joined, "item 'bad_material' is not a seed but names crop 'bad_crop'")
	assert_string_contains(joined, "item 'bad_seed' is a seed of unknown crop 'missing_crop'")
	assert_string_contains(joined, "crop 'bad_crop' harvest item 'berry' is not a CROP item")
	assert_string_contains(joined, "food buff 'bad_buff' changes stat 'typo_speed', which no installed module or the game reads")
	assert_string_contains(joined, "food buff 'bad_buff' has a non-positive multiplier of 'tool_energy'")
	assert_string_contains(joined, "fish 'bad_fish' item 'berry' is no item tagged fish")
	assert_string_contains(joined, "fish 'bad_fish' has an empty time window")
	assert_string_contains(joined, "farm animal 'bad_animal' product 'berry' is no item tagged animal_product")
	assert_string_contains(joined, "farm animal 'bad_animal' has no housing type")
	assert_string_contains(joined, "farm animal 'bad_animal' feed '' is no item tagged animal_feed")
	assert_string_contains(joined, "mining node 'bad_mining' drop 'berry' is no item tagged mined")
	assert_string_contains(joined, "tool upgrade 'bad_upgrade' changes tool action from 'mine' to 'attack'")
	assert_string_contains(joined, "tool upgrade 'bad_upgrade' result power 2 does not exceed source power 2")

func test_entries_report_malformed_numbers_and_schedules_without_crashing() -> void:
	var schedule := NpcScheduleEntry.new()
	schedule.location_id = &"starter_town"
	schedule.days_of_week = PackedInt32Array([8])
	schedule.seasons = PackedStringArray(["Monsoon"])
	schedule.allowed_weather = PackedStringArray(["Hail"])
	var npc := NpcProfileData.new()
	npc.id = &"bad_npc"
	npc.home_location_id = &"starter_town"
	npc.default_location_id = &"starter_town"
	npc.dialogue_titles_by_hearts = {"oops": "bad", 99: "too_high", 2: {"bad": true}}
	npc.schedule_entries = [schedule]
	assert_eq(npc.get_dialogue_title("fallback", 10), "fallback")
	var heart := HeartEventData.new()
	heart.id = &"bad_heart"
	heart.npc_id = &"bad_npc"
	heart.dialogue_title = "bad"
	heart.location_id = &"starter_town"
	heart.required_hearts = 99
	heart.start_minute = 600
	heart.end_minute = 600
	var shop := ShopData.new()
	shop.id = &"bad_shop"
	shop.stock = {"berry": "not-a-price"}
	shop.seasonal_stock = {"Spring": {"berry": {"bad": true}}}
	var recipe := RecipeData.new()
	recipe.id = &"bad_recipe"
	recipe.display_name = "Bad Recipe"
	recipe.ingredients = {"berry": {"bad": true}}
	recipe.output_item_id = &"berry"
	recipe.output_quantity = 0
	var quest := QuestData.new()
	quest.id = &"bad_quest"
	quest.title = ""
	quest.objective_type = QuestData.ObjectiveType.COLLECT
	quest.target_id = &"berry"
	quest.required_amount = 0
	quest.reward_money = -1
	quest.reward_items = {"berry": {"bad": true}}
	quest.entry_point = true
	var event := CalendarEventData.new()
	event.id = &"bad_event"
	event.location_id = &"starter_town"
	event.day_of_season = 99
	event.days_of_week = PackedInt32Array([7])
	event.start_minute = 600
	event.end_minute = 600
	event.reward_money = -1
	event.reward_items = {"berry": {"bad": true}}
	var entries: Array = [npc, heart, shop, recipe, quest, event]
	var joined := _problems_of(_registry_with(entries), entries)
	assert_string_contains(joined, "npc 'bad_npc' dialogue threshold 'oops' is not an integer")
	assert_string_contains(joined, "npc 'bad_npc' dialogue threshold 99 is outside heart range")
	assert_string_contains(joined, "npc 'bad_npc' dialogue threshold 2 has an invalid title")
	assert_string_contains(joined, "npc 'bad_npc' schedule has invalid weekday 8")
	assert_string_contains(joined, "npc 'bad_npc' schedule has unknown season 'Monsoon'")
	assert_string_contains(joined, "npc 'bad_npc' schedule has unknown weather 'Hail'")
	assert_string_contains(joined, "heart event 'bad_heart' has invalid heart requirement 99")
	assert_string_contains(joined, "heart event 'bad_heart' has an invalid time window")
	assert_string_contains(joined, "shop 'bad_shop' has invalid price for 'berry'")
	assert_string_contains(joined, "shop 'bad_shop' has invalid Spring price for 'berry'")
	assert_string_contains(joined, "recipe 'bad_recipe' has invalid ingredient quantity for 'berry'")
	assert_string_contains(joined, "recipe 'bad_recipe' has invalid output quantity 0")
	assert_string_contains(joined, "quest 'bad_quest' has an empty title")
	assert_string_contains(joined, "quest 'bad_quest' has invalid required amount 0")
	assert_string_contains(joined, "quest 'bad_quest' has invalid reward quantity for 'berry'")
	assert_string_contains(joined, "calendar event 'bad_event' has invalid day-of-season 99")
	assert_string_contains(joined, "calendar event 'bad_event' has invalid weekday 7")
	assert_string_contains(joined, "calendar event 'bad_event' has invalid reward quantity for 'berry'")

func test_an_entry_of_no_registered_kind_is_not_indexed() -> void:
	var registry := ContentRegistry.new()
	autofree(registry)
	var item := ItemData.new()
	item.id = &"orphan_item"
	item.resource_path = "res://probe/orphan_item.tres"
	var location := WorldLocationData.new()
	var pack := ContentPack.new()
	pack.entries = [item, location]
	registry.packs = [pack]
	var problems := registry.index()
	assert_eq(problems, PackedStringArray([
		"'res://probe/orphan_item.tres' is of no kind of content an installed module registers",
		"location resource has an empty id: ",
	]))
	assert_null(registry.get_entry(ItemData.KIND, &"orphan_item"))

func test_quest_entry_points_cover_the_entire_registered_graph() -> void:
	var quests := QuestData.find_all()
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

func test_quest_chain_check_reports_orphans_and_invalid_auto_start() -> void:
	var entry := _quest(&"entry", &"chained")
	entry.entry_point = true
	entry.auto_start = true
	var chained := _quest(&"chained", &"")
	var orphan := _quest(&"orphan", &"")
	var problems := QuestData.find_chain_problems(_registry_of([entry, chained, orphan]))
	assert_eq(problems, PackedStringArray(["quest 'orphan' is unreachable from any entry point"]))

	var invalid_auto := _quest(&"invalid_auto", &"")
	invalid_auto.auto_start = true
	var registry := _registry_of([invalid_auto])
	assert_eq(QuestData.find_chain_problems(registry), PackedStringArray(["quest graph has no entry points"]))
	assert_string_contains("\n".join(registry.find_entry_problems(invalid_auto)), "quest 'invalid_auto' auto-starts but is not marked as an entry point")

func test_dependency_cycle_detector_accepts_acyclic_graph_and_ignores_unknown_edges() -> void:
	var graph := {
		"a": ["b"],
		"b": ["c"],
		"c": ["missing_external_reference"],
	}
	assert_eq(ContentRegistry.find_dependency_cycles(graph, "test graph"), PackedStringArray())

func test_dependency_cycle_detector_reports_self_two_node_and_three_node_cycles() -> void:
	assert_eq(ContentRegistry.find_dependency_cycles({"a": ["a"]}, "quest"), PackedStringArray(["quest dependency cycle: a -> a"]))
	assert_eq(ContentRegistry.find_dependency_cycles({"a": ["b"], "b": ["a"]}, "town project"), PackedStringArray(["town project dependency cycle: a -> b -> a"]))
	assert_eq(ContentRegistry.find_dependency_cycles({"a": ["b"], "b": ["c"], "c": ["a"]}, "farm expansion"), PackedStringArray(["farm expansion dependency cycle: a -> b -> c -> a"]))

func test_expansion_tiers_must_climb_within_one_housing() -> void:
	var big := _expansion(&"big", &"coop", 8, [])
	var deluxe := _expansion(&"deluxe", &"coop", 12, [&"big"])
	var duplicate := _expansion(&"duplicate", &"coop", 8, [])
	var wrong_housing := _expansion(&"wrong_housing", &"barn", 12, [&"big"])
	var backwards := _expansion(&"backwards", &"coop", 6, [&"big"])
	var registry := _registry_of([big, deluxe, duplicate, wrong_housing, backwards])
	assert_eq(registry.find_entry_problems(big), PackedStringArray())
	assert_eq(registry.find_entry_problems(deluxe), PackedStringArray())
	assert_eq(registry.find_entry_problems(duplicate), PackedStringArray(["farm expansion 'duplicate' shares housing 'coop' capacity 8 with 'big'"]))
	assert_eq(registry.find_entry_problems(wrong_housing), PackedStringArray(["farm expansion 'wrong_housing' depends on 'big' from different housing 'coop'"]))
	assert_eq(registry.find_entry_problems(backwards), PackedStringArray(["farm expansion 'backwards' capacity 6 does not exceed prerequisite 'big' capacity 8"]))

func test_custom_fields_survive_a_json_round_trip() -> void:
	var item := ItemData.new()
	item.custom_fields = {"rarity": "rare"}
	assert_eq(item.get_custom_field(&"rarity"), "rare")
	assert_eq(item.get_custom_field(&"missing", 3), 3)
	assert_true(ContentDB.get_kinds().has(WorldLocationData.KIND))
	assert_true(ContentDB.get_kinds().has(ItemData.KIND))

## A registry with the game's kinds that indexes the shipped content and
## `entries`, so they can refer to each other and to the shipped content.
func _registry_with(entries: Array) -> ContentRegistry:
	var registry := _registry_of(entries)
	registry.packs.append_array(GameDefinition.current().content)
	assert_eq(registry.index(), PackedStringArray())
	return registry

## A registry with the game's kinds that indexes only `entries`.
func _registry_of(entries: Array) -> ContentRegistry:
	var registry := ContentRegistry.new()
	autofree(registry)
	for kind: StringName in ContentDB.get_kinds():
		registry.register_kind(kind, ContentDB.get_kind_script(kind))
	var pack := ContentPack.new()
	pack.entries.assign(entries)
	registry.packs = [pack]
	assert_eq(registry.index(), PackedStringArray())
	return registry

func _problems_of(registry: ContentRegistry, entries: Array) -> String:
	var problems := PackedStringArray()
	for entry: ContentEntry in entries:
		problems.append_array(registry.find_entry_problems(entry))
	return "\n".join(problems)

func _quest(id: StringName, next_id: StringName) -> QuestData:
	var quest := QuestData.new()
	quest.id = id
	quest.title = String(id)
	quest.next_quest_id = next_id
	return quest

func _expansion(id: StringName, housing_id: StringName, capacity: int, prerequisites: Array[StringName]) -> FarmExpansionData:
	var expansion := FarmExpansionData.new()
	expansion.id = id
	expansion.housing_id = housing_id
	expansion.capacity_after = capacity
	expansion.money_cost = 100
	expansion.prerequisites = prerequisites
	return expansion
