extends GutTest

## The checks the life-sim module's kinds of content and scene nodes make of
## themselves, on broken entries and nodes the test builds.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

func test_tools_of_the_actions_the_module_handles_are_valid() -> void:
	var tools: Array = []
	for action: StringName in [ItemData.ACTION_TILL, ItemData.ACTION_WATER, ItemData.ACTION_MINE, ItemData.ACTION_FISH]:
		var tool := _item(StringName("fixture_%s_tool" % action))
		tool.kind = ItemData.Kind.TOOL
		tool.tool_action = action
		tool.max_stack = 1
		tools.append(tool)
	var registry := ContentFixture.use(self, tools)
	for tool: ItemData in tools:
		assert_eq(registry.find_entry_problems(tool), PackedStringArray(), "the life-sim module handles '%s'" % tool.tool_action)

func test_entries_report_unknown_crops_and_items_without_the_tag_they_need() -> void:
	var berry := _item(&"fixture_berry")
	var bad_seed := _item(&"fixture_bad_seed")
	bad_seed.kind = ItemData.Kind.SEED
	bad_seed.crop_id = &"fixture_missing_crop"
	var bad_crop := CropData.new()
	bad_crop.id = &"fixture_bad_crop"
	bad_crop.harvest_item_id = &"fixture_berry"
	var bad_fish := FishData.new()
	bad_fish.id = &"fixture_bad_fish"
	bad_fish.item_id = &"fixture_berry"
	bad_fish.start_minute = 360
	bad_fish.end_minute = 360
	var bad_animal := FarmAnimalData.new()
	bad_animal.id = &"fixture_bad_animal"
	bad_animal.feed_item_id = &""
	bad_animal.product_item_id = &"fixture_berry"
	var bad_mining := MiningNodeData.new()
	bad_mining.id = &"fixture_bad_mining"
	bad_mining.drop_item_id = &"fixture_berry"
	var entries: Array = [berry, bad_seed, bad_crop, bad_fish, bad_animal, bad_mining]
	var registry := ContentFixture.use(self, entries)
	var joined := _problems_of(registry, entries) + "\n" + "\n".join(CropData.find_seed_problems(registry))
	assert_string_contains(joined, "item 'fixture_bad_seed' is a seed of unknown crop 'fixture_missing_crop'")
	assert_string_contains(joined, "crop 'fixture_bad_crop' harvest item 'fixture_berry' is not a CROP item")
	assert_string_contains(joined, "fish 'fixture_bad_fish' item 'fixture_berry' is no item tagged fish")
	assert_string_contains(joined, "fish 'fixture_bad_fish' has an empty time window")
	assert_string_contains(joined, "farm animal 'fixture_bad_animal' product 'fixture_berry' is no item tagged animal_product")
	assert_string_contains(joined, "farm animal 'fixture_bad_animal' has no housing type")
	assert_string_contains(joined, "farm animal 'fixture_bad_animal' feed '' is no item tagged animal_feed")
	assert_string_contains(joined, "mining node 'fixture_bad_mining' drop 'fixture_berry' is no item tagged mined")

func test_calendar_events_report_malformed_numbers_without_crashing() -> void:
	var meadow := _location(&"fixture_meadow")
	var berry := _item(&"fixture_berry")
	var event := CalendarEventData.new()
	event.id = &"fixture_bad_event"
	event.location_id = &"fixture_meadow"
	event.day_of_season = 99
	event.days_of_week = PackedInt32Array([7])
	event.start_minute = 600
	event.end_minute = 600
	event.reward_money = -1
	event.reward_items = {"fixture_berry": {"bad": true}}
	var entries: Array = [meadow, berry, event]
	var joined := _problems_of(ContentFixture.use(self, entries), entries)
	assert_string_contains(joined, "calendar event 'fixture_bad_event' has invalid day-of-season 99")
	assert_string_contains(joined, "calendar event 'fixture_bad_event' has invalid weekday 7")
	assert_string_contains(joined, "calendar event 'fixture_bad_event' has an invalid time window")
	assert_string_contains(joined, "calendar event 'fixture_bad_event' has negative reward money")
	assert_string_contains(joined, "calendar event 'fixture_bad_event' has invalid reward quantity for 'fixture_berry'")

func test_expansion_tiers_must_climb_within_one_housing() -> void:
	var big := _expansion(&"fixture_big", &"fixture_coop", 8, [])
	var deluxe := _expansion(&"fixture_deluxe", &"fixture_coop", 12, [&"fixture_big"])
	var duplicate := _expansion(&"fixture_duplicate", &"fixture_coop", 8, [])
	var wrong_housing := _expansion(&"fixture_wrong_housing", &"fixture_barn", 12, [&"fixture_big"])
	var backwards := _expansion(&"fixture_backwards", &"fixture_coop", 6, [&"fixture_big"])
	var registry := ContentFixture.use(self, [big, deluxe, duplicate, wrong_housing, backwards])
	assert_eq(registry.find_entry_problems(big), PackedStringArray())
	assert_eq(registry.find_entry_problems(deluxe), PackedStringArray())
	assert_eq(registry.find_entry_problems(duplicate), PackedStringArray(["farm expansion 'fixture_duplicate' shares housing 'fixture_coop' capacity 8 with 'fixture_big'"]))
	assert_eq(registry.find_entry_problems(wrong_housing), PackedStringArray(["farm expansion 'fixture_wrong_housing' depends on 'fixture_big' from different housing 'fixture_coop'"]))
	assert_eq(registry.find_entry_problems(backwards), PackedStringArray(["farm expansion 'fixture_backwards' capacity 6 does not exceed prerequisite 'fixture_big' capacity 8"]))

func test_scene_nodes_report_broken_links() -> void:
	var meadow := _location(&"fixture_meadow")
	var fair := CalendarEventData.new()
	fair.id = &"fixture_fair"
	fair.location_id = &"fixture_riverside"
	var smelt := ProcessingRecipeData.new()
	smelt.id = &"fixture_smelt"
	var registry := ContentFixture.use(self, [meadow, fair, smelt])
	var root := Node2D.new()
	autofree(root)
	var trough := AnimalFeedTrough.new()
	trough.name = "BadTrough"
	trough.housing_id = &"fixture_missing_housing"
	root.add_child(trough)
	var housing := AnimalHousing.new()
	housing.name = "BadHousing"
	housing.housing_id = &"fixture_bad_housing"
	housing.location_id = meadow.id
	root.add_child(housing)
	var mine := MineFloorController.new()
	mine.name = "BadMine"
	mine.floor_spawn_id = &"fixture_missing_spawn"
	root.add_child(mine)
	var field := FarmField.new()
	field.name = "BadField"
	field.field_id = &"fixture_bad_field"
	field.location_id = &"fixture_harbor"
	root.add_child(field)
	var spawner := ForageSpawner.new()
	spawner.name = "BadSpawner"
	spawner.spawner_id = &"fixture_bad_spawner"
	spawner.location_id = &"fixture_harbor"
	root.add_child(spawner)
	var spot := FishingSpot.new()
	spot.name = "BadFishing"
	spot.location_id = &"fixture_harbor"
	root.add_child(spot)
	var booth := CalendarEventBooth.new()
	booth.name = "BadBooth"
	booth.event_id = &"fixture_fair"
	root.add_child(booth)
	var station := ProcessingStation.new()
	station.name = "BadStation"
	station.recipe_ids = [&"fixture_smelt", &"fixture_smelt", &"fixture_missing_recipe"]
	root.add_child(station)
	var joined := "\n".join(registry.find_scene_problems(root, meadow))
	var placed := "\n".join(registry.find_scene_problems(station, null))
	assert_string_contains(joined, "feed trough 'BadTrough' references unknown housing 'fixture_missing_housing'")
	assert_string_contains(joined, "housing 'fixture_bad_housing' needs a display name and a housing type")
	assert_string_contains(joined, "mine 'BadMine' has no entrance spawn")
	assert_string_contains(joined, "mine 'BadMine' names spawn 'fixture_missing_spawn', which its scene does not have")
	assert_string_contains(joined, "farm field 'BadField' references different location 'fixture_harbor'")
	assert_string_contains(joined, "forage spawner 'BadSpawner' references different location 'fixture_harbor'")
	assert_string_contains(joined, "fishing spot 'BadFishing' references different location 'fixture_harbor'")
	assert_string_contains(joined, "event booth 'BadBooth' references event 'fixture_fair' from location 'fixture_riverside'")
	assert_string_contains(joined, "processing station 'BadStation' has no station id")
	assert_string_contains(joined, "processing station 'BadStation' repeats recipe 'fixture_smelt'")
	assert_string_contains(joined, "processing station 'BadStation' references unknown recipe 'fixture_missing_recipe'")
	# A station placed at runtime gets its id from its record.
	assert_false(placed.contains("has no station id"))
	assert_string_contains(placed, "references unknown recipe 'fixture_missing_recipe'")

func _item(id: StringName) -> ItemData:
	var item := ItemData.new()
	item.id = id
	return item

func _location(id: StringName) -> WorldLocationData:
	var location := WorldLocationData.new()
	location.id = id
	return location

func _expansion(id: StringName, housing_id: StringName, capacity: int, prerequisites: Array[StringName]) -> FarmExpansionData:
	var expansion := FarmExpansionData.new()
	expansion.id = id
	expansion.housing_id = housing_id
	expansion.capacity_after = capacity
	expansion.money_cost = 100
	expansion.prerequisites = prerequisites
	return expansion

func _problems_of(registry: ContentRegistry, entries: Array) -> String:
	var problems := PackedStringArray()
	for entry: ContentEntry in entries:
		problems.append_array(registry.find_entry_problems(entry))
	return "\n".join(problems)
