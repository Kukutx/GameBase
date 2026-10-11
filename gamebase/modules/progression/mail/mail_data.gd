class_name MailData
extends ContentEntry

@export var sender_npc_id: StringName
@export var sender_name: String
@export var subject: String
@export_multiline var body: String
@export_range(1, 9999, 1) var available_from_day := 1
@export var required_completed_quest_id: StringName
@export var required_world_flag: StringName
@export var required_world_flag_value := true
@export_range(0, 10, 1) var required_hearts := 0
@export var reward_items: Dictionary = {}
@export_range(0, 999999, 1) var reward_money := 0

func is_available(day: int = -1) -> bool:
	var resolved_day := WorldClock.day if day < 1 else day
	if resolved_day < available_from_day:
		return false
	if required_completed_quest_id != &"" and not QuestState.is_completed(required_completed_quest_id):
		return false
	if required_world_flag != &"" and WorldState.get_bool(required_world_flag) != required_world_flag_value:
		return false
	if required_hearts > 0:
		if sender_npc_id == &"" or RelationshipState.get_hearts(sender_npc_id) < required_hearts:
			return false
	return true

func get_sender_display_name() -> String:
	if not sender_name.is_empty():
		return sender_name
	var profile := ContentDB.get_npc(sender_npc_id)
	return profile.display_name if profile != null else "Unknown"
