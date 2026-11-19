class_name NpcScheduleEntry
extends Resource

@export_range(0, 1439, 1) var minute_of_day := 8 * 60
@export_range(-100, 100, 1) var priority := 0
@export var location_id: StringName
@export var target_position := Vector2.ZERO
@export var activity: String = "Idle"
@export var days_of_week: PackedInt32Array = PackedInt32Array()
@export var seasons: PackedStringArray = PackedStringArray()
## The weather (`WeatherData` ids) the entry holds in; any when empty.
@export var allowed_weather: Array[StringName] = []
## What else must hold for the NPC to follow this entry, in the `GameQuery`
## syntax (`EVENT_ACTIVE harvest_fair`); empty means nothing else.
@export var condition: String = ""

## Whether the NPC may follow this entry on `day` at `minute_of_day`.
func matches(day: int, minute_of_day: int) -> bool:
	if not days_of_week.is_empty() and not days_of_week.has(GameCalendar.current().get_weekday(day)):
		return false
	if not seasons.is_empty() and not seasons.has(GameCalendar.current().get_season_name(day)):
		return false
	if not allowed_weather.is_empty() and not allowed_weather.has(WeatherState.get_weather_id(day)):
		return false
	return GameRules.check(condition, {"day": day, "minute_of_day": minute_of_day})
