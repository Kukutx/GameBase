extends GutTest

var _skills_saved: Dictionary

func before_each() -> void:
	_skills_saved = Skills.to_save_data()

func after_each() -> void:
	Skills.load_save_data(_skills_saved)

func test_skill_levels_follow_thresholds() -> void:
	var skills := SkillManager.new()
	add_child_autofree(skills)
	assert_eq(skills.get_level(&"farming"), 1)
	skills.add_xp(&"farming", 99)
	assert_eq(skills.get_level(&"farming"), 1)
	skills.add_xp(&"farming", 1)
	assert_eq(skills.get_level(&"farming"), 2)
	skills.add_xp(&"farming", 150)
	assert_eq(skills.get_level(&"farming"), 3)

func test_skill_save_round_trip() -> void:
	var source := SkillManager.new()
	add_child_autofree(source)
	source.add_xp(&"foraging", 333)
	var restored := SkillManager.new()
	add_child_autofree(restored)
	restored.load_save_data(source.to_save_data())
	assert_eq(restored.get_xp(&"foraging"), 333)
	assert_eq(restored.get_level(&"foraging"), 3)

func test_skill_load_drops_skills_the_game_does_not_have() -> void:
	var skills := SkillManager.new()
	add_child_autofree(skills)
	var signaled: Array[String] = []
	skills.skill_xp_changed.connect(func(skill: StringName, _xp: int, _level: int) -> void:
		signaled.append(String(skill))
	)
	skills.load_save_data({"farming": 250, "alchemy": 999999})
	assert_eq(skills.get_xp(&"farming"), 250)
	assert_eq(skills.get_xp(&"alchemy"), 0)
	assert_eq(signaled.size(), SkillData.find_all().size())
	assert_false(signaled.has("alchemy"))
	assert_false(skills.to_save_data().has("alchemy"))
	assert_eq(skills.add_xp(&"alchemy", 10), 0, "experience of an unknown skill is ignored")

func test_farm1_lists_its_skills_in_order() -> void:
	var ids: Array[String] = []
	for skill: SkillData in SkillData.find_all():
		ids.append(String(skill.id))
	assert_eq(ids, ["farming", "foraging", "fishing", "mining", "combat", "social"])
	Skills.reset_new_game()
	assert_eq(Skills.get_summary(), "Farm 1 · Gather 1 · Fish 1 · Mine 1 · Combat 1 · Social 1")

func test_skill_data_reports_broken_levels_and_perks() -> void:
	var skill := SkillData.new()
	skill.id = &"broken"
	skill.level_xp = PackedInt32Array([100, 100])
	var unknown := SkillPerk.new()
	unknown.level = 2
	unknown.description = "Unknown stat"
	unknown.multipliers = {&"no_such_stat": 0.9}
	var high := SkillPerk.new()
	high.level = 9
	high.description = "Too high"
	high.bonuses = {&"forage_quantity": 1.0}
	var twin := SkillPerk.new()
	twin.level = 2
	twin.multipliers = {&"tool_energy": 0.0}
	var low := SkillPerk.new()
	low.level = 1
	low.description = "Too low"
	low.bonuses = {&"forage_quantity": 1.0}
	skill.perks = [unknown, high, twin, low, null]
	var problems := "\n".join(skill.find_problems(ContentDB))
	for expected: String in [
		"has no display name",
		"needs a rising, positive experience amount for each level",
		"changes stat 'no_such_stat'",
		"has a level 9 perk above its highest level 3",
		"has two perks at level 2",
		"has a level 2 perk without a description",
		"non-positive multiplier of 'tool_energy'",
		"has an empty perk",
		"has a level 1 perk; a perk unlocks at level 2 or above",
	]:
		assert_string_contains(problems, expected)

func test_farm1_turns_module_events_into_skill_experience() -> void:
	var social := Skills.get_xp(&"social")
	NpcSocialEvents.gift_given.emit(&"mira", &"berry", 0)
	assert_eq(Skills.get_xp(&"social"), social, "a gift that changes nothing earns nothing")
	NpcSocialEvents.gift_given.emit(&"mira", &"berry", 20)
	assert_eq(Skills.get_xp(&"social"), social + 15)
