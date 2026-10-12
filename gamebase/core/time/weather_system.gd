class_name GameWeatherSystem
extends Node

## The weather of each day (`WeatherData`), rolled from the world's seed
## (`GameRandom`) and the chances the game gives per season
## (`GameDefinition.weather_odds`): the same world has the same weather on the
## same day, however often it is asked or loaded. A day the odds give no other
## weather has the game's `GameDefinition.clear_weather_id`; a game that names
## none has no weather (an empty id, and no `WeatherData`).

signal weather_changed(day: int, weather_id: StringName)

# day -> weather id, for the current seed.
var _by_day: Dictionary[int, StringName] = {}
var _today: StringName = &""

func _ready() -> void:
	WorldClock.day_changed.connect(_on_day_changed)
	GameRandom.seed_changed.connect(_on_seed_changed)
	_refresh_for_day(WorldClock.day)

## Whether the running game has weather.
static func has_weather() -> bool:
	return GameDefinition.current().clear_weather_id != &""

## The id of the weather of `day`, of today when -1; empty without weather.
func get_weather_id(day: int = -1) -> StringName:
	if day < 0:
		return _today
	var resolved := maxi(day, 1)
	if not _by_day.has(resolved):
		_by_day[resolved] = _roll(resolved)
	return _by_day[resolved]

## The weather of `day`, of today when -1; null without weather.
func get_weather(day: int = -1) -> WeatherData:
	var weather_id := get_weather_id(day)
	return WeatherData.find(weather_id) if weather_id != &"" else null

## Whether the weather of `day` (today when -1) waters the ground outside.
func is_ground_wet(day: int = -1) -> bool:
	var weather := get_weather(day)
	return weather != null and weather.wets_ground

## The name of the weather of `day` (today when -1), untranslated; empty
## without weather.
func get_weather_name(day: int = -1) -> String:
	var weather := get_weather(day)
	return weather.display_name if weather != null else ""

## Problems with the weather `definition` gives: odds without a clear weather,
## a weather that is no `WeatherData` of `registry`, an unknown or repeated
## season, or chances outside 0-1 or above 1 together.
static func find_problems(definition: GameDefinition, registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if definition.clear_weather_id == &"":
		if not definition.weather_odds.is_empty():
			problems.append("the game rolls weather but names no clear weather")
	elif not registry.has_entry(WeatherData.KIND, definition.clear_weather_id):
		problems.append("the game's clear weather '%s' is no weather" % definition.clear_weather_id)
	var seen: Dictionary[String, bool] = {}
	for entry: WeatherOdds in definition.weather_odds:
		if entry == null:
			problems.append("the game lists empty weather odds")
			continue
		if not GameCalendar.current().has_season(entry.season):
			problems.append("weather odds name unknown season '%s'" % entry.season)
		elif seen.has(entry.season):
			problems.append("weather odds list season '%s' twice" % entry.season)
		seen[entry.season] = true
		var total := 0.0
		var valid := true
		for weather_id: StringName in entry.chances:
			if not registry.has_entry(WeatherData.KIND, weather_id):
				problems.append("weather odds of '%s' name unknown weather '%s'" % [entry.season, weather_id])
			var chance: float = entry.chances[weather_id]
			valid = valid and chance >= 0.0
			total += chance
		if not valid or total > 1.0:
			problems.append("weather odds of '%s' are not chances that add up to at most 1" % entry.season)
	return problems

# The chances are rolled in the order the odds list them, so the same odds
# give the same weather.
func _roll(day: int) -> StringName:
	var definition := GameDefinition.current()
	var season := GameCalendar.current().get_season_name(day)
	for odds: WeatherOdds in definition.weather_odds:
		if odds != null and odds.season == season:
			var roll := GameRandom.stream("weather:%d" % day).randf()
			var reach := 0.0
			for weather_id: StringName in odds.chances:
				reach += odds.chances[weather_id]
				if roll < reach:
					return weather_id
			break
	return definition.clear_weather_id

func _on_day_changed(day: int) -> void:
	_refresh_for_day(day)

func _on_seed_changed(_world_seed: int) -> void:
	_by_day.clear()
	_refresh_for_day(WorldClock.day)

func _refresh_for_day(day: int) -> void:
	_today = get_weather_id(maxi(day, 1))
	weather_changed.emit(day, _today)
