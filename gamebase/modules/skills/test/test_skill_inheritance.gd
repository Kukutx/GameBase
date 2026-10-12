extends GutTest

## Skill experience carried over to a new playthrough or a sequel
## (`SkillInheritance`).

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

var _skills: Dictionary

func before_each() -> void:
	_skills = Skills.to_save_data()
	var skill := SkillData.new()
	skill.id = &"fixture_digging"
	skill.display_name = "Digging"
	skill.level_xp = PackedInt32Array([10, 20, 30])
	ContentFixture.use(self, [skill])
	Skills.reset_new_game()

func after_each() -> void:
	# GUT frees the fixture content only after this hook.
	ContentRegistry.active = ContentDB
	Skills.load_save_data(_skills)

func test_it_carries_a_share_of_the_experience() -> void:
	var rule := SkillInheritance.new()
	rule.percent = 50
	Skills.add_xp(&"fixture_digging", 25)
	var carried: Variant = rule.capture()
	assert_eq(carried, {"fixture_digging": 12})
	Skills.reset_new_game()
	Skills.add_xp(&"fixture_digging", 3)
	watch_signals(GameEvents)
	rule.apply(carried)
	assert_eq(Skills.get_xp(&"fixture_digging"), 15, "added to what the new game has")
	assert_signal_not_emitted(GameEvents, "toast_requested", "a new game levels up without a word")
	rule.apply({"fixture_digging": "lots", "fixture_gone": 9})
	rule.apply(null)
	assert_eq(Skills.get_xp(&"fixture_digging"), 15)
