class_name FishData
extends ContentEntry

const KIND := &"fish"

@export var item_id: StringName
@export var locations: Array[StringName] = []
@export var seasons: PackedStringArray = PackedStringArray()
@export_range(0, 1439, 1) var start_minute := 6 * 60
@export_range(1, 1440, 1) var end_minute := 22 * 60
@export var allowed_weather: PackedStringArray = PackedStringArray()
@export_range(0.01, 100.0, 0.01) var catch_weight := 1.0
@export_range(1, 10, 1) var difficulty := 1

## The fish with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> FishData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as FishData

## The running game's fish, sorted by id.
static func find_all() -> Array[FishData]:
	var result: Array[FishData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

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

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if not ItemData.has_tagged(registry, item_id, "fish"):
		problems.append("item '%s' is no item tagged fish" % item_id)
	if start_minute == end_minute:
		problems.append("has an empty time window")
	if catch_weight <= 0.0:
		problems.append("has non-positive catch weight")
	if difficulty <= 0:
		problems.append("has invalid difficulty")
	for location_id: StringName in locations:
		if not registry.has_entry(WorldLocationData.KIND, location_id):
			problems.append("references unknown location '%s'" % location_id)
	for season: String in seasons:
		if not GameClock.SEASON_NAMES.has(season):
			problems.append("has unknown season '%s'" % season)
	for weather_name: String in allowed_weather:
		if not GameWeatherSystem.WEATHER_NAMES.has(weather_name):
			problems.append("has unknown weather '%s'" % weather_name)
	return problems
