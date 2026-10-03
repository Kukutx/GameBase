class_name NpcScheduleEntry
extends Resource

@export_range(0, 1439, 1) var minute_of_day := 8 * 60
@export_range(-100, 100, 1) var priority := 0
@export var location_id: StringName
@export var target_position := Vector2.ZERO
@export var activity: String = "Idle"
@export var days_of_week: PackedInt32Array = PackedInt32Array()
@export var seasons: PackedStringArray = PackedStringArray()
@export var allowed_weather: PackedStringArray = PackedStringArray()
@export var required_world_flag: StringName
@export var required_flag_value := true

func matches_day(day: int) -> bool:
	if not days_of_week.is_empty() and not days_of_week.has(posmod(maxi(day, 1) - 1, 7)):
		return false
	if not seasons.is_empty() and not seasons.has(GameClock.get_season_name_for_day(day)):
		return false
	if not allowed_weather.is_empty():
		var weather_name := WeatherState.get_weather_name(WeatherState.get_weather_for_day(day))
		if not allowed_weather.has(weather_name):
			return false
	if required_world_flag != &"" and WorldState.get_bool(required_world_flag) != required_flag_value:
		return false
	return true
