class_name GameClock
extends Node

signal minute_changed(day: int, minute_of_day: int)
signal hour_changed(day: int, hour: int)
signal day_changed(day: int)

const MINUTES_PER_DAY := 24 * 60
const DAYS_PER_SEASON := 28
const SEASON_NAMES := ["Spring", "Summer", "Autumn", "Winter"]

@export_range(0.05, 10.0, 0.05) var real_seconds_per_game_minute := 0.7

var day := 1
var minute_of_day := 8 * 60
var paused := false
var _elapsed := 0.0

func _process(delta: float) -> void:
	if paused or real_seconds_per_game_minute <= 0.0:
		return
	_elapsed += delta
	while _elapsed >= real_seconds_per_game_minute:
		_elapsed -= real_seconds_per_game_minute
		_advance_one_minute()

func advance_minutes(amount: int) -> void:
	for _index in range(maxi(amount, 0)):
		_advance_one_minute()

func set_time(new_day: int, new_minute_of_day: int) -> void:
	var normalized_day := maxi(new_day, 1)
	var normalized_minute := posmod(new_minute_of_day, MINUTES_PER_DAY)
	var old_day := day
	var old_hour := get_hour()
	day = normalized_day
	minute_of_day = normalized_minute
	_elapsed = 0.0
	if day != old_day:
		day_changed.emit(day)
	if get_hour() != old_hour or day != old_day:
		hour_changed.emit(day, get_hour())
	minute_changed.emit(day, minute_of_day)

func get_hour() -> int:
	return minute_of_day / 60

func get_minute() -> int:
	return minute_of_day % 60

func get_time_text() -> String:
	return "Day %d  %02d:%02d" % [day, get_hour(), get_minute()]

func get_calendar_text() -> String:
	return "%s %d  %02d:%02d" % [get_season_name(), get_day_of_season(), get_hour(), get_minute()]

func get_season_index() -> int:
	return get_season_index_for_day(day)

func get_season_name() -> String:
	return get_season_name_for_day(day)

func get_day_of_season() -> int:
	return posmod(day - 1, DAYS_PER_SEASON) + 1

static func get_season_index_for_day(target_day: int) -> int:
	return posmod((maxi(target_day, 1) - 1) / DAYS_PER_SEASON, SEASON_NAMES.size())

static func get_season_name_for_day(target_day: int) -> String:
	return String(SEASON_NAMES[get_season_index_for_day(target_day)])

func get_day_progress() -> float:
	return float(minute_of_day) / float(MINUTES_PER_DAY)

func is_night() -> bool:
	return minute_of_day < 6 * 60 or minute_of_day >= 20 * 60

func to_save_data() -> Dictionary:
	return {
		"day": day,
		"minute_of_day": minute_of_day,
	}

func load_save_data(data: Dictionary) -> void:
	var raw_day: Variant = data.get("day", 1)
	var raw_minute: Variant = data.get("minute_of_day", 8 * 60)
	var loaded_day := int(raw_day) if typeof(raw_day) == TYPE_INT or typeof(raw_day) == TYPE_FLOAT else 1
	var loaded_minute := int(raw_minute) if typeof(raw_minute) == TYPE_INT or typeof(raw_minute) == TYPE_FLOAT else 8 * 60
	set_time(loaded_day, loaded_minute)

func _advance_one_minute() -> void:
	var previous_hour := get_hour()
	minute_of_day += 1
	if minute_of_day >= MINUTES_PER_DAY:
		minute_of_day = 0
		day += 1
		day_changed.emit(day)
	if get_hour() != previous_hour:
		hour_changed.emit(day, get_hour())
	minute_changed.emit(day, minute_of_day)
