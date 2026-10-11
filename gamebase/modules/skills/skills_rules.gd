class_name SkillsRules
extends RefCounted

## Condition and action keys of the skills module (see `GameRulesService`).

## Rule argument kinds: a skill id, and a level a skill can reach.
const ARG_SKILL := &"skill"
const ARG_SKILL_LEVEL := &"skill_level"

static func register(rules: GameRulesService) -> void:
	rules.register_arg_kind(ARG_SKILL, _check_skill)
	rules.register_arg_kind(ARG_SKILL_LEVEL, _check_level)
	rules.register_condition(&"SKILL_LEVEL", _skill_level, 2, 2, [ARG_SKILL, ARG_SKILL_LEVEL], _describe_skill_level)
	rules.register_action(&"ADD_SKILL_XP", _add_skill_xp, 2, 2, [ARG_SKILL, GameRulesService.ARG_INT])

static func _check_skill(value: String) -> String:
	return "" if SkillManager.SKILL_IDS.has(StringName(value)) else "unknown skill '%s'" % value

static func _check_level(value: String) -> String:
	var max_level := SkillManager.LEVEL_THRESHOLDS.size()
	if value.is_valid_int() and int(value) >= 1 and int(value) <= max_level:
		return ""
	return "'%s' is not a skill level (1-%d)" % [value, max_level]

## SKILL_LEVEL <skill> <level>: the skill has reached at least the level.
static func _skill_level(args: PackedStringArray, _context: Dictionary) -> bool:
	return Skills.get_level(StringName(args[0])) >= int(args[1])

static func _describe_skill_level(args: PackedStringArray) -> String:
	return "%s Lv%d" % [Skills.get_skill_name(StringName(args[0])), int(args[1])]

## ADD_SKILL_XP <skill> <amount>
static func _add_skill_xp(args: PackedStringArray, _context: Dictionary) -> bool:
	Skills.add_xp(StringName(args[0]), int(args[1]))
	return true
