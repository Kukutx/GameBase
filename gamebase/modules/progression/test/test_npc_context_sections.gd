extends GutTest

## What the progression module adds to an NPC's conversation context.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

var _quest_snapshot: Dictionary

func before_each() -> void:
	_quest_snapshot = QuestState.to_save_data()
	var npc := NpcProfileData.new()
	npc.id = &"fixture_npc"
	npc.display_name = "Fixture"
	var quest := QuestData.new()
	quest.id = &"fixture_errand"
	quest.title = "Errand"
	var project := TownProjectData.new()
	project.id = &"fixture_garden"
	project.display_name = "Fixture Garden"
	project.requirements = {"fixture_twig": 2}
	ContentFixture.use(self, [npc, quest, project])
	QuestState.load_save_data({})

func after_each() -> void:
	# The game's content is active again before the quests load.
	ContentRegistry.active = ContentDB
	QuestState.load_save_data(_quest_snapshot)

func test_npc_context_includes_the_quest_journal_and_town_projects() -> void:
	assert_true(QuestState.start_quest(&"fixture_errand"))
	var context := NpcContext.build_context(&"fixture_npc")
	assert_true(context["quests"] is Array, "the progression module adds the quest journal")
	assert_true(context["town_projects"] is Array, "the progression module adds town projects")
	var quests: Array = context["quests"]
	assert_eq(quests.size(), 1)
	assert_eq(String((quests[0] as Dictionary).get("id", "")), "fixture_errand")
	var projects: Array = context["town_projects"]
	assert_eq(projects.size(), 1)
	assert_eq(String((projects[0] as Dictionary).get("id", "")), "fixture_garden")
