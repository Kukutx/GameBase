class_name FishData
extends ContentEntry

## A fish the player may catch (`FishingService`): its item, and where, in
## which seasons, at what time of day and in what weather it bites; of the fish
## that bite at once, one is rolled by `catch_weight`, and its `difficulty`
## sets how hard the reel minigame is.

const KIND := &"fish"

## The item (`ItemData`, tagged `fish`) a catch gives.
@export var item_id: StringName
## The locations (`WorldLocationData`) it bites in; empty, any.
@export var locations: Array[StringName] = []
## The seasons of the game's calendar it bites in; empty, every season.
@export var seasons: PackedStringArray = PackedStringArray()
## When it bites, in minutes after midnight; a window that ends before it
## starts runs past midnight.
@export_range(0, 1439, 1) var start_minute := 6 * 60
@export_range(1, 1440, 1) var end_minute := 22 * 60
## The weather (`WeatherData` ids) it bites in; any when empty.
@export var allowed_weather: Array[StringName] = []
## How likely it bites against the other fish that bite there and then.
@export_range(0.01, 100.0, 0.01) var catch_weight := 1.0
## How hard its reel minigame is: a smaller catch zone and a faster marker.
@export_range(1, 10, 1) var difficulty := 1

## The fish with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> FishData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as FishData

## The running game's fish, sorted by id.
static func find_all() -> Array[FishData]:
	var result: Array[FishData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func is_available(location_id: StringName, day: int, minute_of_day: int, weather_id: StringName) -> bool:
	if not locations.is_empty() and not locations.has(location_id):
		return false
	var season := GameCalendar.current().get_season_name(day)
	if not seasons.is_empty() and not seasons.has(season):
		return false
	if not allowed_weather.is_empty() and not allowed_weather.has(weather_id):
		return false
	if start_minute <= end_minute:
		return minute_of_day >= start_minute and minute_of_day < end_minute
	return minute_of_day >= start_minute or minute_of_day < end_minute

## When it bites, in words the player reads ("Spring, Autumn · 06:00–20:00 ·
## Rain"): its seasons, its hours unless it bites all day, and its weather, of
## `registry`'s content; "" when it bites at any time.
func describe_when(registry: ContentRegistry = ContentRegistry.active) -> String:
	var parts := PackedStringArray()
	var season_names := PackedStringArray()
	for season: String in seasons:
		season_names.append(String(TranslationServer.translate(season)))
	if not season_names.is_empty():
		parts.append(GameText.list(season_names))
	if start_minute != 0 or end_minute != 24 * 60:
		parts.append("%s–%s" % [_clock(start_minute), _clock(end_minute)])
	var weather_names := PackedStringArray()
	for weather_id: StringName in allowed_weather:
		var weather := registry.get_entry(WeatherData.KIND, weather_id) as WeatherData if registry != null else null
		weather_names.append(String(TranslationServer.translate(weather.display_name)) if weather != null else String(weather_id))
	if not weather_names.is_empty():
		parts.append(GameText.list(weather_names))
	return " · ".join(parts)

# "06:00" for `minute` after midnight; midnight at the end of the day too.
static func _clock(minute: int) -> String:
	return "%02d:%02d" % [int(minute / 60.0) % 24, minute % 60]

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
		if not GameCalendar.current().has_season(season):
			problems.append("has unknown season '%s'" % season)
	for weather_id: StringName in allowed_weather:
		if not registry.has_entry(WeatherData.KIND, weather_id):
			problems.append("has unknown weather '%s'" % weather_id)
	return problems
