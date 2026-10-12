class_name GameClock
extends Node

signal minute_changed(day: int, minute_of_day: int)
signal hour_changed(day: int, hour: int)
signal day_changed(day: int)

## The world's clock: the day and the minute of the day, run by real time
## while not paused. How the days group into seasons and weeks, how fast
## minutes pass and when night falls is the game's `GameCalendar`.

const MINUTES_PER_DAY := 24 * 60

var day := 1
var minute_of_day := 8 * 60
var paused := false
var _elapsed := 0.0

func _process(delta: float) -> void:
	var minute_length := GameCalendar.current().real_seconds_per_game_minute
	if paused or minute_length <= 0.0:
		return
	_elapsed += delta
	while _elapsed >= minute_length:
		_elapsed -= minute_length
		_advance_one_minute()

## Runs the clock `amount` minutes on, each minute as if it passed.
func advance_minutes(amount: int) -> void:
	for _index in range(maxi(amount, 0)):
		_advance_one_minute()

## Runs the clock on, each minute as if it passed, until `condition` (a
## `GameRules` query, asked about the clock's day and minute) holds, for at
## most `limit` minutes: waiting for the evening, the next market day or a
## festival. Returns how many minutes passed, or -1 when the condition did not
## hold within the limit (the clock then stands `limit` minutes on). While the
## player is up, the wait also ends at the calendar's collapse minute, where
## they collapse, with -1, even when the condition would hold there. A
## condition that is not a valid query moves nothing.
func advance_until(condition: String, limit: int) -> int:
	var problems := GameRules.validate_query(condition)
	if not GameRulesService.find_event_arg_uses(PackedStringArray([condition])).is_empty():
		problems.append("only a trigger's conditions name event arguments ($name)")
	if not problems.is_empty():
		push_warning("GameClock: cannot wait until '%s': %s" % [condition, "; ".join(problems)])
		return -1
	var collapse_minute := GameCalendar.current().collapse_minute
	for passed: int in range(maxi(limit, 0) + 1):
		if passed > 0 and minute_of_day == collapse_minute and get_tree().get_first_node_in_group(&"player") != null:
			return -1
		if GameRules.check(condition, {"day": day, "minute_of_day": minute_of_day}):
			return passed
		if passed < limit:
			_advance_one_minute()
	return -1

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

## The date (`GameCalendar.get_date_text()`) and the time of day, translated.
func get_calendar_text() -> String:
	return "%s  %02d:%02d" % [GameCalendar.current().get_date_text(day), get_hour(), get_minute()]

func get_season_index() -> int:
	return GameCalendar.current().get_season_index(day)

func get_season_name() -> String:
	return GameCalendar.current().get_season_name(day)

func get_day_of_season() -> int:
	return GameCalendar.current().get_day_of_season(day)

func get_year() -> int:
	return GameCalendar.current().get_year(day)

func get_weekday() -> int:
	return GameCalendar.current().get_weekday(day)

func get_day_progress() -> float:
	return float(minute_of_day) / float(MINUTES_PER_DAY)

func is_night() -> bool:
	return GameCalendar.current().is_night(minute_of_day)

func to_save_data() -> Dictionary:
	return {
		"day": day,
		"minute_of_day": minute_of_day,
	}

func load_save_data(data: Dictionary) -> void:
	var raw_day: Variant = data.get("day", 1)
	var raw_minute: Variant = data.get("minute_of_day", GameDefinition.current().start_minute_of_day)
	var loaded_day := int(raw_day) if typeof(raw_day) == TYPE_INT or typeof(raw_day) == TYPE_FLOAT else 1
	var loaded_minute := int(raw_minute) if typeof(raw_minute) == TYPE_INT or typeof(raw_minute) == TYPE_FLOAT else GameDefinition.current().start_minute_of_day
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
