class_name FishData
extends Resource

@export var id: StringName
@export var item_id: StringName
@export var locations: Array[StringName] = []
@export var seasons: PackedStringArray = PackedStringArray()
@export_range(0, 1439, 1) var start_minute := 6 * 60
@export_range(1, 1440, 1) var end_minute := 22 * 60
@export var allowed_weather: PackedStringArray = PackedStringArray()
@export_range(0.01, 100.0, 0.01) var catch_weight := 1.0
@export_range(1, 10, 1) var difficulty := 1

func is_available(location_id: StringName, day: int, minute_of_day: int, weather_name: String) -> bool:
	if not locations.is_empty() and not locations.has(location_id):
		return false
	var season := GameClock.get_season_name_for_day(day)
	if not seasons.is_empty() and not seasons.has(season):
		return false
	if not allowed_weather.is_empty() and not allowed_weather.has(weather_name):
		return false
	if start_minute <= end_minute:
		return minute_of_day >= start_minute and minute_of_day < end_minute
	return minute_of_day >= start_minute or minute_of_day < end_minute
