class_name QuestData
extends Resource

enum ObjectiveType {
	COLLECT,
	TALK,
	HARVEST,
	FISH,
	MINE,
	DEFEAT,
	PROCESS,
	UPGRADE,
	REACH_MINE_FLOOR,
}

@export var id: StringName
@export var title: String
@export_multiline var description: String
@export_group("Start")
@export var entry_point := false
@export var auto_start := false
@export_group("Objective")
@export var objective_type: ObjectiveType = ObjectiveType.COLLECT
@export var target_id: StringName
@export_range(1, 999, 1) var required_amount := 1
@export_range(0, 999999, 1) var reward_money := 0
@export var reward_items: Dictionary = {}
@export var next_quest_id: StringName
