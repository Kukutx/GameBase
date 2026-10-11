class_name ProgressionRules
extends RefCounted

## Condition and action keys of the progression module (see `GameRulesService`).

static func register(rules: GameRulesService) -> void:
	rules.register_condition(&"QUEST_ACTIVE", _quest_active, 1, 1, [&"quest"])
	rules.register_condition(&"QUEST_COMPLETED", _quest_completed, 1, 1, [&"quest"])
	rules.register_condition(&"SKILL_LEVEL", _skill_level, 2, 2, [GameRulesService.ARG_TEXT, GameRulesService.ARG_INT])
	rules.register_action(&"START_QUEST", _start_quest, 1, 1, [&"quest"])
	rules.register_action(&"ADD_SKILL_XP", _add_skill_xp, 2, 2, [GameRulesService.ARG_TEXT, GameRulesService.ARG_INT])

## QUEST_ACTIVE <quest>
static func _quest_active(args: PackedStringArray, _context: Dictionary) -> bool:
	return QuestState.is_active(StringName(args[0]))

## QUEST_COMPLETED <quest>
static func _quest_completed(args: PackedStringArray, _context: Dictionary) -> bool:
	return QuestState.is_completed(StringName(args[0]))

## SKILL_LEVEL <skill> <level>: the skill has reached at least the level.
static func _skill_level(args: PackedStringArray, _context: Dictionary) -> bool:
	return Skills.get_level(StringName(args[0])) >= int(args[1])

## START_QUEST <quest>: fails when the quest already started.
static func _start_quest(args: PackedStringArray, _context: Dictionary) -> bool:
	return QuestState.start_quest(StringName(args[0]))

## ADD_SKILL_XP <skill> <amount>
static func _add_skill_xp(args: PackedStringArray, _context: Dictionary) -> bool:
	Skills.add_xp(StringName(args[0]), int(args[1]))
	return true
