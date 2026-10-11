class_name GameWeatherSystem
extends Node

## The weather of each day, rolled from the world's seed (`GameRandom`) and the
## odds the game gives per season (`GameDefinition.weather_odds`): the same
## world has the same weather on the same day, however often it is asked or
## loaded. A season the game gives no odds for is always clear.

enum Weather {
	CLEAR,
	RAIN,
	STORM,
}

signal weather_changed(day: int, weather: Weather)

## The name of each `Weather`, in its order, as content names weather.
const WEATHER_NAMES: Array[String] = ["Clear", "Rain", "Storm"]

var current_weather: Weather = Weather.CLEAR

# day -> Weather, for the current seed.
var _by_day: Dictionary = {}

func _ready() -> void:
	WorldClock.day_changed.connect(_on_day_changed)
	GameRandom.seed_changed.connect(_on_seed_changed)
	_refresh_for_day(WorldClock.day)

func get_weather_for_day(day: int) -> Weather:
	var resolved := maxi(day, 1)
	if not _by_day.has(resolved):
		_by_day[resolved] = _roll(resolved)
	return _by_day[resolved]

func is_raining(day: int = -1) -> bool:
	var weather := current_weather if day < 0 else get_weather_for_day(day)
	return weather == Weather.RAIN or weather == Weather.STORM

func get_weather_name(weather: Weather = current_weather) -> String:
	return WEATHER_NAMES[weather]

## Problems with a game's weather odds: an unknown or repeated season, a chance
## outside 0-1, or rain and storm together above 1.
static func find_odds_problems(odds: Array[WeatherOdds]) -> PackedStringArray:
	var problems := PackedStringArray()
	var seen: Dictionary = {}
	for entry: WeatherOdds in odds:
		if entry == null:
			problems.append("the game lists empty weather odds")
			continue
		if not GameCalendar.current().has_season(entry.season):
			problems.append("weather odds name unknown season '%s'" % entry.season)
		elif seen.has(entry.season):
			problems.append("weather odds list season '%s' twice" % entry.season)
		seen[entry.season] = true
		if entry.rain < 0.0 or entry.storm < 0.0 or entry.rain + entry.storm > 1.0:
			problems.append("weather odds of '%s' are not chances that add up to at most 1" % entry.season)
	return problems

func _roll(day: int) -> Weather:
	var season := GameCalendar.current().get_season_name(day)
	for odds: WeatherOdds in GameDefinition.current().weather_odds:
		if odds != null and odds.season == season:
			var roll := GameRandom.stream("weather:%d" % day).randf()
			if roll < odds.storm:
				return Weather.STORM
			if roll < odds.storm + odds.rain:
				return Weather.RAIN
			break
	return Weather.CLEAR

func _on_day_changed(day: int) -> void:
	_refresh_for_day(day)

func _on_seed_changed(_world_seed: int) -> void:
	_by_day.clear()
	_refresh_for_day(WorldClock.day)

func _refresh_for_day(day: int) -> void:
	current_weather = get_weather_for_day(day)
	weather_changed.emit(day, current_weather)
