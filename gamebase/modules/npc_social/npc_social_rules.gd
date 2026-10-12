class_name NpcSocialRules
extends RefCounted

## Condition and action keys of the NPC social module (see `GameRulesService`).

static func register(rules: GameRulesService) -> void:
	rules.register_condition(&"HEARTS", _hearts, 2, 2, [NpcProfileData.KIND, GameRulesService.ARG_INT], Callable(), _check_hearts)
	rules.register_action(&"ADD_FRIENDSHIP", _add_friendship, 2, 2, [NpcProfileData.KIND, GameRulesService.ARG_INT])

## HEARTS <npc> <n>: the friendship with the NPC has at least n hearts.
static func _hearts(args: PackedStringArray, _context: Dictionary) -> bool:
	return RelationshipState.get_hearts(StringName(args[0])) >= int(args[1])

# A friendship reaches 0 to MAX_HEARTS hearts.
static func _check_hearts(args: PackedStringArray) -> String:
	var hearts := int(args[1])
	if hearts >= 0 and hearts <= RelationshipManager.MAX_HEARTS:
		return ""
	return "%d is not a number of hearts (0-%d)" % [hearts, RelationshipManager.MAX_HEARTS]

## ADD_FRIENDSHIP <npc> <points>: adds the points to the friendship with the NPC,
## or takes them away when negative; the friendship stays between 0 and full
## hearts (`RelationshipManager.POINTS_PER_HEART` points a heart). Never fails.
static func _add_friendship(args: PackedStringArray, _context: Dictionary) -> bool:
	RelationshipState.add_friendship(StringName(args[0]), int(args[1]))
	return true
