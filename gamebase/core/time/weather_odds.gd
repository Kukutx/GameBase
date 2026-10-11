class_name WeatherOdds
extends Resource

## How likely rain and storms are on a day of one season. A storm is rain too;
## what is left of the day's odds is clear weather.

## Season name, one of `GameClock.SEASON_NAMES`.
@export var season: String = ""
@export_range(0.0, 1.0, 0.01) var rain := 0.0
@export_range(0.0, 1.0, 0.01) var storm := 0.0
