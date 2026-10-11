extends GutTest

## The condition and action keys the progression module registers
## (`ProgressionRules`), and the check of the conditions content names.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

func test_quest_keys_are_registered_and_checked_against_content() -> void:
	var quest := QuestData.new()
	quest.id = &"fixture_first_quest"
	quest.title = "First"
	ContentFixture.use(self, [quest])
	for key: String in ["QUEST_ACTIVE", "QUEST_COMPLETED"]:
		assert_true(GameRules.has_condition(StringName(key)), key)
	assert_true(GameRules.has_action(&"START_QUEST"))
	assert_eq(GameRules.validate_query("!QUEST_COMPLETED fixture_first_quest, QUEST_ACTIVE fixture_first_quest"), PackedStringArray())
	assert_eq(GameRules.validate_actions(PackedStringArray(["START_QUEST fixture_first_quest"])), PackedStringArray())
	assert_string_contains("\n".join(GameRules.validate_query("QUEST_ACTIVE no_such_quest")), "unknown quest 'no_such_quest'")

func test_project_and_milestone_keys_are_checked_against_content() -> void:
	var project := TownProjectData.new()
	project.id = &"fixture_garden"
	var milestone := CollectionMilestoneData.new()
	milestone.id = &"fixture_archive"
	ContentFixture.use(self, [project, milestone])
	assert_eq(GameRules.validate_query("PROJECT_COMPLETED fixture_garden, !MILESTONE_CLAIMED fixture_archive"), PackedStringArray())
	var problems := "\n".join(GameRules.validate_query("PROJECT_COMPLETED fixture_archive, MILESTONE_CLAIMED fixture_garden"))
	assert_string_contains(problems, "unknown town_project 'fixture_archive'")
	assert_string_contains(problems, "unknown collection_milestone 'fixture_garden'")

func test_content_validation_finds_conditions_in_nested_resources() -> void:
	var item := ItemData.new()
	item.id = &"fixture_berry"
	var entry := NpcScheduleEntry.new()
	entry.condition = "TYPO_KEY"
	var profile := NpcProfileData.new()
	profile.id = &"rules_test_npc"
	profile.schedule_entries = [entry]
	var mail := MailData.new()
	mail.id = &"rules_test_mail"
	mail.condition = "HAS_ITEM fixture_berry"
	var registry := ContentFixture.use(self, [item, profile, mail])
	var problems := GameRules.validate_content(registry)
	assert_eq(problems.size(), 1)
	assert_string_contains("\n".join(problems), "npc 'rules_test_npc' schedule_entries condition: unknown condition 'TYPO_KEY'")
