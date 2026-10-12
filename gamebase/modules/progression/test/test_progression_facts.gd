extends GutTest

## What the progression module tells about the game (`GameModule.get_facts()`):
## the quest journal and the town projects.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

var _quest_snapshot: Dictionary

func before_each() -> void:
	_quest_snapshot = QuestState.to_save_data()
	var quest := QuestData.new()
	quest.id = &"fixture_errand"
	quest.title = "Errand"
	var talk := QuestObjective.new()
	talk.event = &"NpcSocialEvents.npc_talked"
	quest.objectives = [talk]
	var project := TownProjectData.new()
	project.id = &"fixture_garden"
	project.display_name = "Fixture Garden"
	project.requirements = {"fixture_twig": 2}
	ContentFixture.use(self, [quest, project])
	QuestState.load_save_data({})

func after_each() -> void:
	# The game's content is active again before the quests load.
	ContentRegistry.active = ContentDB
	QuestState.load_save_data(_quest_snapshot)

func test_the_module_tells_the_quest_journal_and_the_town_projects() -> void:
	assert_true(QuestState.start_quest(&"fixture_errand"))
	var facts := ProgressionModule.new().get_facts()
	assert_eq(facts.keys(), ["quests", "town_projects"])
	assert_eq(facts["quests"], QuestState.get_journal_entries())
	assert_eq((facts["quests"] as Array).map(func(quest: Dictionary) -> String: return quest["id"]), ["fixture_errand"])
	assert_eq(facts["town_projects"], TownProjects.get_context_entries())
	assert_eq((facts["town_projects"] as Array).map(func(project: Dictionary) -> String: return project["id"]), ["fixture_garden"])
