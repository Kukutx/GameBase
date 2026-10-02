class_name HeartEventData
extends Resource

@export var id: StringName
@export var npc_id: StringName
@export_range(0, 10, 1) var required_hearts := 2
@export var dialogue_title: String = "heart_event"
@export var location_id: StringName
@export var seasons: PackedStringArray = []
@export_range(0, 1439, 1) var start_minute := 0
@export_range(1, 1440, 1) var end_minute := 1440
@export var required_world_flag: StringName
@export var required_flag_value := true

func matches(target_npc_id: StringName, hearts: int, target_location_id: StringName, day: int, minute_of_day: int) -> bool:
	if id == &"" or npc_id == &"" or target_npc_id != npc_id:
		return false
	if hearts < required_hearts:
		return false
	if location_id != &"" and target_location_id != location_id:
		return false
	if not seasons.is_empty() and not seasons.has(GameClock.get_season_name_for_day(day)):
		return false
	if minute_of_day < start_minute or minute_of_day >= end_minute:
		return false
	if required_world_flag != &"" and WorldState.get_bool(required_world_flag) != required_flag_value:
		return false
	return true
