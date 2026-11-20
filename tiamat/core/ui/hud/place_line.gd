class_name PlaceLine
extends HudLine

## Where the player is and when: the location's name, what the scene adds
## about where the player stands (its `get_place_detail() -> String`, such as
## a mine's floor), the date and the time (`WorldClock.get_calendar_text()`)
## and, on a line that shows it, the day's weather (`WeatherState`).

@export var shows_place := true
@export var shows_time := true
@export var shows_weather := false

func _watch() -> void:
	if shows_time:
		watch(WorldClock.minute_changed)
	if shows_weather:
		watch(WeatherState.weather_changed)

func _get_parts() -> PackedStringArray:
	var parts := PackedStringArray()
	if shows_place:
		var location := WorldLocationData.find_current(get_tree())
		parts.append(tr(location.display_name) if location != null else "")
	var scene := get_tree().current_scene
	if scene != null and scene.has_method(&"get_place_detail"):
		parts.append(String(scene.call(&"get_place_detail")))
	if shows_time:
		parts.append(WorldClock.get_calendar_text())
	if shows_weather:
		parts.append(tr(WeatherState.get_weather_name()))
	return parts
