extends GutTest

## The checks the progression module's kinds of content and scene nodes make
## of themselves, and the quest chain check, on broken entries and nodes the
## test builds.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

func test_entries_report_invalid_rewards_and_tool_changes() -> void:
	var meadow := WorldLocationData.new()
	meadow.id = &"fixture_meadow"
	var berry := _item(&"fixture_berry")
	var source_tool := _tool(&"fixture_source_tool", &"fixture_dig", 2)
	var result_tool := _tool(&"fixture_result_tool", &"fixture_till", 2)
	var bad_mail := MailData.new()
	bad_mail.id = &"fixture_bad_mail"
	bad_mail.subject = "Bad"
	bad_mail.body = "Bad"
	bad_mail.reward_items = {"fixture_berry": 0}
	var bad_project := TownProjectData.new()
	bad_project.id = &"fixture_bad_project"
	bad_project.location_id = &"fixture_meadow"
	bad_project.requirements = {"fixture_berry": 1}
	bad_project.reward_items = {"fixture_berry": -1}
	var bad_upgrade := ToolUpgradeData.new()
	bad_upgrade.id = &"fixture_bad_upgrade"
	bad_upgrade.source_item_id = &"fixture_source_tool"
	bad_upgrade.result_item_id = &"fixture_result_tool"
	var entries: Array = [meadow, berry, source_tool, result_tool, bad_mail, bad_project, bad_upgrade]
	var joined := _problems_of(ContentFixture.use(self, entries), entries)
	assert_string_contains(joined, "mail 'fixture_bad_mail' has invalid reward quantity for 'fixture_berry'")
	assert_string_contains(joined, "town project 'fixture_bad_project' has invalid reward quantity for 'fixture_berry'")
	assert_string_contains(joined, "tool upgrade 'fixture_bad_upgrade' changes tool action from 'fixture_dig' to 'fixture_till'")
	assert_string_contains(joined, "tool upgrade 'fixture_bad_upgrade' result power 2 does not exceed source power 2")

func test_quests_report_malformed_numbers_and_objectives_without_crashing() -> void:
	var berry := _item(&"fixture_berry")
	var quest := QuestData.new()
	quest.id = &"fixture_bad_quest"
	quest.title = ""
	quest.reward_money = -1
	quest.reward_items = {"fixture_berry": {"bad": true}}
	quest.entry_point = true
	var gather := QuestObjective.new()
	gather.event = &"InventoryState.item_gained"
	gather.condition = "EVENT_ARG item_id fixture_berry fixture_retired_item"
	gather.count_per = &"item_id"
	gather.required_amount = 0
	var hoard := QuestObjective.new()
	hoard.event = &"InventoryState.changed"
	hoard.measure = &"InventoryState.add_item_by_id"
	var nowhere := QuestObjective.new()
	nowhere.event = &"FixtureNoAutoload.happened"
	quest.objectives = [gather, hoard, nowhere]
	var empty := QuestData.new()
	empty.id = &"fixture_empty_quest"
	empty.title = "Empty"
	var entries: Array = [berry, quest, empty]
	var joined := _problems_of(ContentFixture.use(self, entries), entries)
	assert_string_contains(joined, "quest 'fixture_bad_quest' has an empty title")
	assert_string_contains(joined, "quest 'fixture_bad_quest' objective 1 requires 0; an objective requires at least 1")
	assert_string_contains(joined, "quest 'fixture_bad_quest' objective 1 compares argument 'item_id' with unknown item 'fixture_retired_item'")
	assert_false(joined.contains("unknown item 'fixture_berry'"), "an id of the kind passes")
	assert_string_contains(joined, "quest 'fixture_bad_quest' objective 1 counts per 'item_id', which is no integer argument of 'InventoryState.item_gained'")
	assert_string_contains(joined, "quest 'fixture_bad_quest' objective 2 follows 'InventoryState.add_item_by_id', which is no method of an autoload that takes no argument and returns an int")
	assert_string_contains(joined, "quest 'fixture_bad_quest' objective 3 listens to 'FixtureNoAutoload.happened', which is no signal of an autoload")
	assert_string_contains(joined, "quest 'fixture_empty_quest' has no objectives")
	assert_string_contains(joined, "quest 'fixture_bad_quest' objective 2 has no description; each of several objectives says what it asks")
	assert_string_contains(joined, "quest 'fixture_bad_quest' has negative reward money")
	assert_string_contains(joined, "quest 'fixture_bad_quest' has invalid reward quantity for 'fixture_berry'")

func test_quest_chain_check_reports_orphans_and_invalid_auto_start() -> void:
	var entry := _quest(&"fixture_entry", &"fixture_chained")
	entry.entry_point = true
	entry.auto_start = true
	var chained := _quest(&"fixture_chained", &"")
	var orphan := _quest(&"fixture_orphan", &"")
	var problems := QuestData.find_chain_problems(ContentFixture.use(self, [entry, chained, orphan]))
	assert_eq(problems, PackedStringArray(["quest 'fixture_orphan' is unreachable from any entry point"]))

	var invalid_auto := _quest(&"fixture_invalid_auto", &"")
	invalid_auto.auto_start = true
	var registry := ContentFixture.use(self, [invalid_auto])
	assert_eq(QuestData.find_chain_problems(registry), PackedStringArray(["quest graph has no entry points"]))
	assert_string_contains("\n".join(registry.find_entry_problems(invalid_auto)), "quest 'fixture_invalid_auto' auto-starts but is not marked as an entry point")

func test_a_town_project_board_reports_another_location() -> void:
	var meadow := WorldLocationData.new()
	meadow.id = &"fixture_meadow"
	var registry := ContentFixture.use(self, [meadow])
	var root := Node2D.new()
	autofree(root)
	var board := TownProjectBoard.new()
	board.name = "Board"
	board.location_id = &"fixture_meadow"
	root.add_child(board)
	var bad_board := TownProjectBoard.new()
	bad_board.name = "BadBoard"
	bad_board.location_id = &"fixture_harbor"
	root.add_child(bad_board)
	assert_eq(registry.find_scene_problems(root, meadow), PackedStringArray(["town project board 'BadBoard' references different location 'fixture_harbor'"]))

func test_a_project_completion_visual_reports_an_unknown_project() -> void:
	var garden := TownProjectData.new()
	garden.id = &"fixture_garden"
	var registry := ContentFixture.use(self, [garden])
	var root := Node2D.new()
	autofree(root)
	var visual := ProjectCompletionVisual.new()
	visual.name = "Garden"
	visual.project_id = &"fixture_garden"
	root.add_child(visual)
	var bad_visual := ProjectCompletionVisual.new()
	bad_visual.name = "Ruin"
	bad_visual.project_id = &"fixture_ruin"
	root.add_child(bad_visual)
	assert_eq(registry.find_scene_problems(root, null), PackedStringArray(["project completion visual 'Ruin' references unknown town project 'fixture_ruin'"]))

func _item(id: StringName) -> ItemData:
	var item := ItemData.new()
	item.id = id
	return item

func _tool(id: StringName, action: StringName, power: int) -> ItemData:
	var tool := _item(id)
	tool.kind = ItemData.Kind.TOOL
	tool.tool_action = action
	tool.tool_power = power
	tool.max_stack = 1
	return tool

func _quest(id: StringName, next_id: StringName) -> QuestData:
	var quest := QuestData.new()
	quest.id = id
	quest.title = String(id)
	quest.next_quest_id = next_id
	return quest

func _problems_of(registry: ContentRegistry, entries: Array) -> String:
	var problems := PackedStringArray()
	for entry: ContentEntry in entries:
		problems.append_array(registry.find_entry_problems(entry))
	return "\n".join(problems)
