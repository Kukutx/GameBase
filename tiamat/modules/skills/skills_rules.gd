class_name SkillsRules
extends RefCounted

## Condition and action keys of the skills module (see `GameRulesService`).

## Rule argument kind: a skill id.
const ARG_SKILL := &"skill"

static func register(rules: GameRulesService) -> void:
	rules.register_arg_kind(ARG_SKILL, _check_skill)
	rules.register_condition(&"SKILL_LEVEL", _skill_level, 2, 2, [ARG_SKILL, GameRulesService.ARG_INT], _describe_skill_level, _check_skill_level)
	rules.register_action(&"ADD_SKILL_XP", _add_skill_xp, 2, 2, [ARG_SKILL, GameRulesService.ARG_INT])

static func _check_skill(value: String) -> String:
	return "" if SkillData.find(StringName(value)) != null else "unknown skill '%s'" % value

# The level must be one the named skill reaches.
static func _check_skill_level(args: PackedStringArray) -> String:
	var skill := SkillData.find(StringName(args[0]))
	var level := int(args[1])
	if level >= 1 and level <= skill.get_max_level():
		return ""
	return "skill '%s' has no level %d (1-%d)" % [args[0], level, skill.get_max_level()]

## SKILL_LEVEL <skill> <level>: the skill has reached at least the level.
static func _skill_level(args: PackedStringArray, _context: Dictionary) -> bool:
	return Skills.get_level(StringName(args[0])) >= int(args[1])

static func _describe_skill_level(args: PackedStringArray) -> String:
	return "%s Lv%d" % [Skills.get_skill_name(StringName(args[0])), int(args[1])]

## ADD_SKILL_XP <skill> <amount>: gives the skill that much experience, which can
## raise its level; an amount of 0 or less gives none, and the action still
## succeeds.
static func _add_skill_xp(args: PackedStringArray, _context: Dictionary) -> bool:
	Skills.add_xp(StringName(args[0]), int(args[1]))
	return true
