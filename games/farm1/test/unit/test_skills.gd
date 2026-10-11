extends GutTest

var _skills_saved: Dictionary

func before_each() -> void:
	_skills_saved = Skills.to_save_data()

func after_each() -> void:
	Skills.load_save_data(_skills_saved)

func test_skill_levels_follow_thresholds() -> void:
	var skills := SkillManager.new()
	add_child_autofree(skills)
	assert_eq(skills.get_level(SkillManager.FARMING), 1)
	skills.add_xp(SkillManager.FARMING, 99)
	assert_eq(skills.get_level(SkillManager.FARMING), 1)
	skills.add_xp(SkillManager.FARMING, 1)
	assert_eq(skills.get_level(SkillManager.FARMING), 2)
	skills.add_xp(SkillManager.FARMING, 150)
	assert_eq(skills.get_level(SkillManager.FARMING), 3)

func test_skill_save_round_trip() -> void:
	var source := SkillManager.new()
	add_child_autofree(source)
	source.add_xp(SkillManager.FORAGING, 333)
	var restored := SkillManager.new()
	add_child_autofree(restored)
	restored.load_save_data(source.to_save_data())
	assert_eq(restored.get_xp(SkillManager.FORAGING), 333)
	assert_eq(restored.get_level(SkillManager.FORAGING), 3)
	assert_eq(int(restored.to_save_data().get("__level:foraging", 0)), 3)

func test_skill_load_ignores_unknown_current_schema_keys_and_signals_only_known_skills() -> void:
	var skills := SkillManager.new()
	add_child_autofree(skills)
	var signaled: Array[String] = []
	skills.skill_xp_changed.connect(func(skill: StringName, _xp: int, _level: int) -> void:
		signaled.append(String(skill))
	)
	skills.load_save_data({
		"farming": 250,
		"alchemy": 999999,
		"__level:farming": 3,
		"__level:alchemy": 10,
	})
	assert_eq(skills.get_xp(SkillManager.FARMING), 250)
	assert_eq(skills.get_xp(&"alchemy"), 0)
	assert_eq(signaled.size(), SkillManager.SKILL_IDS.size())
	assert_false(signaled.has("alchemy"))
	var saved := skills.to_save_data()
	assert_false(saved.has("alchemy"))
	assert_false(saved.has("__level:alchemy"))

func test_skill_level_entitlement_is_backfilled_and_never_regresses() -> void:
	var legacy := SkillManager.new()
	add_child_autofree(legacy)
	legacy.load_save_data({"farming": 700})
	assert_eq(legacy.get_level(SkillManager.FARMING), 5)
	assert_eq(int(legacy.to_save_data().get("__level:farming", 0)), 5)

	var rebalanced := SkillManager.new()
	add_child_autofree(rebalanced)
	rebalanced.load_save_data({"farming": 100, "__level:farming": 5})
	assert_eq(rebalanced.get_xp(SkillManager.FARMING), 100)
	assert_eq(rebalanced.get_level(SkillManager.FARMING), 5)
	assert_eq(rebalanced.get_perk_tier(SkillManager.FARMING), 1)
	assert_eq(int(rebalanced.to_save_data().get("__level:farming", 0)), 5)

	# New XP can still legitimately advance beyond the preserved entitlement.
	rebalanced.add_xp(SkillManager.FARMING, 900)
	assert_eq(rebalanced.get_level(SkillManager.FARMING), 6)
	assert_eq(int(rebalanced.to_save_data().get("__level:farming", 0)), 6)

func test_farm1_turns_module_events_into_skill_experience() -> void:
	var social := Skills.get_xp(SkillManager.SOCIAL)
	NpcSocialEvents.gift_given.emit(&"mira", &"berry", 0)
	assert_eq(Skills.get_xp(SkillManager.SOCIAL), social, "a gift that changes nothing earns nothing")
	NpcSocialEvents.gift_given.emit(&"mira", &"berry", 20)
	assert_eq(Skills.get_xp(SkillManager.SOCIAL), social + 15)
