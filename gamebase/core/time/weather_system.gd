class_name GameWeatherSystem
extends Node

enum Weather {
	CLEAR,
	RAIN,
	STORM,
}

signal weather_changed(day: int, weather: Weather)

## The name of each `Weather`, in its order, as content names weather.
const WEATHER_NAMES: Array[String] = ["Clear", "Rain", "Storm"]

var world_seed := 93017
var current_weather: Weather = Weather.CLEAR

func _ready() -> void:
	WorldClock.day_changed.connect(_on_day_changed)
	_refresh_for_day(WorldClock.day)

func get_weather_for_day(day: int) -> Weather:
	var rng := RandomNumberGenerator.new()
	var season := GameClock.get_season_index_for_day(day)
	rng.seed = hash("%d:%d:%d" % [world_seed, maxi(day, 1), season])
	var roll := rng.randf()
	match season:
		0: # Spring
			if roll < 0.05:
				return Weather.STORM
			if roll < 0.30:
				return Weather.RAIN
		1: # Summer
			if roll < 0.04:
				return Weather.STORM
			if roll < 0.16:
				return Weather.RAIN
		2: # Autumn
			if roll < 0.07:
				return Weather.STORM
			if roll < 0.34:
				return Weather.RAIN
		3: # Winter
			if roll < 0.02:
				return Weather.STORM
			if roll < 0.12:
				return Weather.RAIN
	return Weather.CLEAR

func is_raining(day: int = -1) -> bool:
	var weather := current_weather if day < 0 else get_weather_for_day(day)
	return weather == Weather.RAIN or weather == Weather.STORM

func get_weather_name(weather: Weather = current_weather) -> String:
	return WEATHER_NAMES[weather]

func to_save_data() -> Dictionary:
	return {"world_seed": world_seed}

func load_save_data(data: Dictionary) -> void:
	var raw_seed: Variant = data.get("world_seed", 93017)
	world_seed = int(raw_seed) if typeof(raw_seed) == TYPE_INT or typeof(raw_seed) == TYPE_FLOAT else 93017
	_refresh_for_day(WorldClock.day)

func _on_day_changed(day: int) -> void:
	_refresh_for_day(day)

func _refresh_for_day(day: int) -> void:
	var next := get_weather_for_day(day)
	current_weather = next
	weather_changed.emit(day, current_weather)
