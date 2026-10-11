extends GutTest

## The condition and action keys the skills module registers (`SkillsRules`).

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

func before_each() -> void:
	ContentFixture.use(self, [_skill(&"fixture_digging", "Digging"), _skill(&"fixture_tilling", "Tilling")])

func test_skill_keys_are_registered() -> void:
	assert_true(GameRules.has_condition(&"SKILL_LEVEL"))
	assert_true(GameRules.has_action(&"ADD_SKILL_XP"))

func test_skill_argument_kinds_check_skills_and_levels() -> void:
	assert_eq(GameRules.validate_query("SKILL_LEVEL fixture_tilling 10"), PackedStringArray())
	var problems := "\n".join(GameRules.validate_query("SKILL_LEVEL fixture_tilling 11, SKILL_LEVEL cooking 2"))
	assert_string_contains(problems, "condition 'SKILL_LEVEL': skill 'fixture_tilling' has no level 11 (1-10)")
	assert_string_contains(problems, "unknown skill 'cooking'")
	assert_string_contains("\n".join(GameRules.validate_actions(PackedStringArray(["ADD_SKILL_XP sewing 5"]))), "unknown skill 'sewing'")

func test_a_skill_level_is_checked_against_that_skill_s_own_levels() -> void:
	var short := _skill(&"fixture_whistling", "Whistling")
	short.level_xp = PackedInt32Array([100, 200])
	ContentFixture.use(self, [short])
	assert_eq(GameRules.validate_query("SKILL_LEVEL fixture_whistling 3"), PackedStringArray())
	assert_eq(GameRules.validate_query("SKILL_LEVEL fixture_whistling 4"),
		PackedStringArray(["condition 'SKILL_LEVEL': skill 'fixture_whistling' has no level 4 (1-3)"]))
	assert_eq(GameRules.validate_query("SKILL_LEVEL fixture_whistling 0"),
		PackedStringArray(["condition 'SKILL_LEVEL': skill 'fixture_whistling' has no level 0 (1-3)"]))

func test_describe_lists_what_a_skill_condition_requires() -> void:
	assert_eq(GameRules.describe("SKILL_LEVEL fixture_digging 3, WORLD_FLAG test:rules_flag, !SKILL_LEVEL fixture_tilling 2"), PackedStringArray(["Digging Lv3"]))

## A skill with levels 1 to 10.
func _skill(id: StringName, display_name: String) -> SkillData:
	var skill := SkillData.new()
	skill.id = id
	skill.display_name = display_name
	skill.level_xp = PackedInt32Array([100, 200, 300, 400, 500, 600, 700, 800, 900])
	return skill
