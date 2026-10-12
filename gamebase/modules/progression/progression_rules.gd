class_name ProgressionRules
extends RefCounted

## Condition and action keys of the progression module (see `GameRulesService`).

static func register(rules: GameRulesService) -> void:
	rules.register_condition(&"QUEST_ACTIVE", _quest_active, 1, 1, [QuestData.KIND])
	rules.register_condition(&"QUEST_COMPLETED", _quest_completed, 1, 1, [QuestData.KIND])
	rules.register_condition(&"PROJECT_COMPLETED", _project_completed, 1, 1, [TownProjectData.KIND])
	rules.register_condition(&"MILESTONE_CLAIMED", _milestone_claimed, 1, 1, [CollectionMilestoneData.KIND])
	rules.register_action(&"START_QUEST", _start_quest, 1, 1, [QuestData.KIND])

## QUEST_ACTIVE <quest>: the quest has started and is not completed yet.
static func _quest_active(args: PackedStringArray, _context: Dictionary) -> bool:
	return QuestState.is_active(StringName(args[0]))

## QUEST_COMPLETED <quest>: the quest is completed and its reward was given.
static func _quest_completed(args: PackedStringArray, _context: Dictionary) -> bool:
	return QuestState.is_completed(StringName(args[0]))

## PROJECT_COMPLETED <town_project>: the town gathered everything the project needs.
static func _project_completed(args: PackedStringArray, _context: Dictionary) -> bool:
	return TownProjects.is_completed(StringName(args[0]))

## MILESTONE_CLAIMED <collection_milestone>: the player claimed the milestone's reward.
static func _milestone_claimed(args: PackedStringArray, _context: Dictionary) -> bool:
	return CollectionMilestones.is_claimed(StringName(args[0]))

## START_QUEST <quest>: fails when the quest already started.
static func _start_quest(args: PackedStringArray, _context: Dictionary) -> bool:
	return QuestState.start_quest(StringName(args[0]))
