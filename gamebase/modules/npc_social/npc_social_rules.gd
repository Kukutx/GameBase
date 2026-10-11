class_name NpcSocialRules
extends RefCounted

## Condition and action keys of the NPC social module (see `GameRulesService`).

static func register(rules: GameRulesService) -> void:
	rules.register_condition(&"HEARTS", _hearts, 2, 2, [&"npc", GameRulesService.ARG_INT])
	rules.register_action(&"ADD_FRIENDSHIP", _add_friendship, 2, 2, [&"npc", GameRulesService.ARG_INT])

## HEARTS <npc> <n>: the friendship with the NPC has at least n hearts.
static func _hearts(args: PackedStringArray, _context: Dictionary) -> bool:
	return RelationshipState.get_hearts(StringName(args[0])) >= int(args[1])

## ADD_FRIENDSHIP <npc> <points>
static func _add_friendship(args: PackedStringArray, _context: Dictionary) -> bool:
	RelationshipState.add_friendship(StringName(args[0]), int(args[1]))
	return true
