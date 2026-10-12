class_name ProfileRules
extends RefCounted

## Condition and action keys of the player's profile (`GameProfile`), which
## outlives every save (see `GameRulesService`).

static func register(rules: GameRulesService) -> void:
	rules.register_condition(&"ACHIEVEMENT_UNLOCKED", _achievement_unlocked, 1, 1, [AchievementData.KIND])
	rules.register_condition(&"PROFILE_FLAG", _profile_flag, 1, 2, [GameRulesService.ARG_TEXT, GameRulesService.ARG_BOOL])
	rules.register_condition(&"PROFILE_FLAG_AT_LEAST", _profile_flag_at_least, 2, 2, [GameRulesService.ARG_TEXT, GameRulesService.ARG_INT])
	rules.register_action(&"UNLOCK_ACHIEVEMENT", _unlock_achievement, 1, 1, [AchievementData.KIND])
	rules.register_action(&"SET_PROFILE_FLAG", _set_profile_flag, 1, 2, [GameRulesService.ARG_TEXT, GameRulesService.ARG_FLAG_VALUE])
	rules.register_action(&"ADD_PROFILE_FLAG", _add_profile_flag, 1, 2, [GameRulesService.ARG_TEXT, GameRulesService.ARG_INT])

## ACHIEVEMENT_UNLOCKED <achievement>: the player unlocked it, in any save.
static func _achievement_unlocked(args: PackedStringArray, _context: Dictionary) -> bool:
	return GameProfile.is_unlocked(StringName(args[0]))

## PROFILE_FLAG <key> [true|false]: the profile's boolean flag has the value
## (default true).
static func _profile_flag(args: PackedStringArray, _context: Dictionary) -> bool:
	return GameProfile.get_bool(StringName(args[0])) == (GameRulesService.to_bool(args[1]) if args.size() > 1 else true)

## PROFILE_FLAG_AT_LEAST <key> <n>: the profile's counter is at least n.
static func _profile_flag_at_least(args: PackedStringArray, _context: Dictionary) -> bool:
	return GameProfile.get_int(StringName(args[0])) >= int(args[1])

## UNLOCK_ACHIEVEMENT <achievement>: unlocks the achievement in the player's
## profile, for every save; one already unlocked stays so and the action still
## succeeds. Fails only when the id is not an achievement.
static func _unlock_achievement(args: PackedStringArray, _context: Dictionary) -> bool:
	return GameProfile.unlock(StringName(args[0]))

## SET_PROFILE_FLAG <key> [value]: value is true, false or an integer (default true).
static func _set_profile_flag(args: PackedStringArray, _context: Dictionary) -> bool:
	var value: Variant = true
	if args.size() > 1:
		value = int(args[1]) if args[1].is_valid_int() else GameRulesService.to_bool(args[1])
	GameProfile.set_flag(StringName(args[0]), value)
	return true

## ADD_PROFILE_FLAG <key> [n]: adds n (default 1) to the profile's counter.
static func _add_profile_flag(args: PackedStringArray, _context: Dictionary) -> bool:
	GameProfile.add_int(StringName(args[0]), int(args[1]) if args.size() > 1 else 1)
	return true
