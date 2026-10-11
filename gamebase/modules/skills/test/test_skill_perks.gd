extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const SKILL := &"fixture_digging"
## Stats the fixture perks change; a stat need not be registered to be read.
const STAMINA := &"fixture_stamina"
const YIELD := &"fixture_yield"

var _skill_snapshot: Dictionary
var _first: SkillPerk
var _second: SkillPerk

func before_each() -> void:
	_skill_snapshot = Skills.to_save_data()
	_first = _perk(3, "Digger I", 0.9, 1.0)
	_second = _perk(5, "Digger II", 0.8, 2.0)
	var skill := SkillData.new()
	skill.id = SKILL
	skill.display_name = "Digging"
	skill.level_xp = PackedInt32Array([10, 20, 30, 40])
	skill.perks = [_second, _first]
	ContentFixture.use(self, [skill])
	Skills.reset_new_game()

func after_each() -> void:
	# GUT frees the fixture content only after this hook.
	ContentRegistry.active = ContentDB
	Skills.load_save_data(_skill_snapshot)

func test_skill_perks_unlock_at_their_levels_and_change_stats() -> void:
	assert_null(Skills.get_active_perk(SKILL))
	assert_eq(GameStats.get_multiplier(STAMINA), 1.0)
	assert_eq(GameStats.get_bonus(YIELD), 0.0)
	assert_eq(Skills.get_perk_summary(SKILL), "Next passive at Lv3")

	Skills.add_xp(SKILL, 20)
	assert_eq(Skills.get_level(SKILL), 3)
	assert_eq(Skills.get_active_perk(SKILL), _first)
	assert_almost_eq(GameStats.get_multiplier(STAMINA), 0.9, 0.001)
	assert_almost_eq(GameStats.apply(YIELD, 2.0), 3.0, 0.001)
	assert_eq(Skills.get_perk_summary(SKILL), "Digger I")

	Skills.add_xp(SKILL, 20)
	assert_eq(Skills.get_level(SKILL), 5)
	assert_eq(Skills.get_active_perk(SKILL), _second, "a later perk takes the earlier one's place")
	assert_almost_eq(GameStats.get_multiplier(STAMINA), 0.8, 0.001)
	assert_almost_eq(GameStats.apply(YIELD, 2.0), 4.0, 0.001)
	assert_eq(Skills.get_perk_summary(SKILL), "Digger II")

	Skills.reset_new_game()
	assert_null(Skills.get_active_perk(SKILL))
	assert_eq(GameStats.get_multiplier(STAMINA), 1.0)

static func _perk(level: int, description: String, multiplier: float, bonus: float) -> SkillPerk:
	var perk := SkillPerk.new()
	perk.level = level
	perk.description = description
	perk.multipliers = {STAMINA: multiplier}
	perk.bonuses = {YIELD: bonus}
	return perk
