class_name WeatherOdds
extends Resource

## The chances of each weather on a day of one season, by weather id
## (`WeatherData`), rolled in the order they are listed; what is left of the
## day's odds is the game's `GameDefinition.clear_weather_id`.

## Season name, one of the game's calendar (`GameCalendar.season_names`).
@export var season: String = ""
## Weather id -> its chance on a day of the season, from 0 to 1.
@export var chances: Dictionary[StringName, float] = {}
