extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
## A stat registered for the test, so a perk may change it.
const STAT := &"fixture_stamina"

var _registered_stat := false

func before_each() -> void:
	ContentFixture.use(self, [
		_skill(&"fixture_tilling", "Tilling", [100, 250, 450]),
		_skill(&"fixture_gathering", "Gathering", [100, 250, 450]),
	])

func after_each() -> void:
	# GUT frees the fixture content only after this hook.
	ContentRegistry.active = ContentDB
	if _registered_stat:
		# GameStats has no way to forget a stat; the test registered this one.
		(GameStats.get("_stats") as Dictionary).erase(STAT)
		_registered_stat = false

func test_skill_levels_follow_thresholds() -> void:
	var skills := SkillManager.new()
	add_child_autofree(skills)
	assert_eq(skills.get_level(&"fixture_tilling"), 1)
	skills.add_xp(&"fixture_tilling", 99)
	assert_eq(skills.get_level(&"fixture_tilling"), 1)
	skills.add_xp(&"fixture_tilling", 1)
	assert_eq(skills.get_level(&"fixture_tilling"), 2)
	skills.add_xp(&"fixture_tilling", 150)
	assert_eq(skills.get_level(&"fixture_tilling"), 3)

func test_skill_save_round_trip() -> void:
	var source := SkillManager.new()
	add_child_autofree(source)
	source.add_xp(&"fixture_gathering", 333)
	var restored := SkillManager.new()
	add_child_autofree(restored)
	restored.load_save_data(source.to_save_data())
	assert_eq(restored.get_xp(&"fixture_gathering"), 333)
	assert_eq(restored.get_level(&"fixture_gathering"), 3)

func test_skill_load_drops_skills_the_game_does_not_have() -> void:
	var skills := SkillManager.new()
	add_child_autofree(skills)
	var signaled: Array[String] = []
	skills.skill_xp_changed.connect(func(skill: StringName, _xp: int, _level: int) -> void:
		signaled.append(String(skill))
	)
	skills.load_save_data({"fixture_tilling": 250, "alchemy": 999999})
	assert_eq(skills.get_xp(&"fixture_tilling"), 250)
	assert_eq(skills.get_xp(&"alchemy"), 0)
	assert_eq(signaled.size(), SkillData.find_all().size())
	assert_false(signaled.has("alchemy"))
	assert_false(skills.to_save_data().has("alchemy"))
	assert_eq(skills.add_xp(&"alchemy", 10), 0, "experience of an unknown skill is ignored")

func test_skill_data_reports_broken_levels_and_perks() -> void:
	_registered_stat = not GameStats.has_stat(STAT)
	GameStats.register_stat(STAT)
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
	high.bonuses = {STAT: 1.0}
	var twin := SkillPerk.new()
	twin.level = 2
	twin.multipliers = {STAT: 0.0}
	var low := SkillPerk.new()
	low.level = 1
	low.description = "Too low"
	low.bonuses = {STAT: 1.0}
	skill.perks = [unknown, high, twin, low, null]
	var problems := "\n".join(skill.find_problems(ContentRegistry.active))
	for expected: String in [
		"has no display name",
		"needs a rising, positive experience amount for each level",
		"changes stat 'no_such_stat'",
		"has a level 9 perk above its highest level 3",
		"has two perks at level 2",
		"has a level 2 perk without a description",
		"non-positive multiplier of '%s'" % STAT,
		"has an empty perk",
		"has a level 1 perk; a perk unlocks at level 2 or above",
	]:
		assert_string_contains(problems, expected)

static func _skill(id: StringName, display_name: String, level_xp: Array) -> SkillData:
	var skill := SkillData.new()
	skill.id = id
	skill.display_name = display_name
	skill.level_xp = PackedInt32Array(level_xp)
	return skill
