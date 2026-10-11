extends GutTest

var _skills_saved: Dictionary

func before_each() -> void:
	_skills_saved = Skills.to_save_data()

func after_each() -> void:
	Skills.load_save_data(_skills_saved)

func test_farm1_lists_its_skills_in_order() -> void:
	var ids: Array[String] = []
	for skill: SkillData in SkillData.find_all():
		ids.append(String(skill.id))
	assert_eq(ids, ["farming", "foraging", "fishing", "mining", "combat", "social"])
	Skills.reset_new_game()
	assert_eq(Skills.get_summary(), "Farm 1 · Gather 1 · Fish 1 · Mine 1 · Combat 1 · Social 1")

func test_farm1_turns_module_events_into_skill_experience() -> void:
	var social := Skills.get_xp(&"social")
	NpcSocialEvents.gift_given.emit(&"mira", &"berry", 0)
	assert_eq(Skills.get_xp(&"social"), social, "a gift that changes nothing earns nothing")
	NpcSocialEvents.gift_given.emit(&"mira", &"berry", 20)
	assert_eq(Skills.get_xp(&"social"), social + 15)
