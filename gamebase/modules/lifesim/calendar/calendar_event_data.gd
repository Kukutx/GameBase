class_name CalendarEventData
extends ContentEntry

@export var display_name: String
@export var location_id: StringName
@export var seasons: PackedStringArray = PackedStringArray()
@export_range(0, 28, 1) var day_of_season := 0
@export var days_of_week: PackedInt32Array = PackedInt32Array()
@export_range(0, 1439, 1) var start_minute := 9 * 60
@export_range(1, 1440, 1) var end_minute := 17 * 60

@export_group("Participation Reward")
@export_range(0, 999999, 1) var reward_money := 0
@export var reward_items: Dictionary = {}
@export var reward_skill: StringName
@export_range(0, 9999, 1) var reward_skill_xp := 0

func has_participation_reward() -> bool:
	return reward_money > 0 or not reward_items.is_empty() or (reward_skill != &"" and reward_skill_xp > 0)

func is_active(day: int, minute_of_day: int) -> bool:
	if not seasons.is_empty() and not seasons.has(GameClock.get_season_name_for_day(day)):
		return false
	if day_of_season > 0 and posmod(maxi(day, 1) - 1, GameClock.DAYS_PER_SEASON) + 1 != day_of_season:
		return false
	if not days_of_week.is_empty() and not days_of_week.has(posmod(maxi(day, 1) - 1, 7)):
		return false
	return minute_of_day >= start_minute and minute_of_day < end_minute
