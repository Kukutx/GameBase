class_name GameCalendar
extends Resource

## How a game counts its time: its seasons and how long they last, its week,
## how fast the clock runs, when night falls and when the player's day starts
## and ends. A game sets one as `GameDefinition.calendar`; the clock, the time
## conditions (SEASON, DAY_OF_SEASON, WEEKDAY) and every content check of a
## season name read it through `GameCalendar.current()`. The clock counts in
## minutes and a day always has 24 hours (`GameClock.MINUTES_PER_DAY`).

## The seasons in their order; one year is all of them. A game without seasons
## lists one.
@export var season_names: PackedStringArray = PackedStringArray(["Spring", "Summer", "Autumn", "Winter"])
@export_range(1, 1000) var days_per_season := 28
## Days in a week (`WEEKDAY` counts 0 to this minus one; day 1 is weekday 0).
@export_range(1, 100) var days_per_week := 7
## Real seconds one game minute lasts while the clock runs.
@export_range(0.01, 60.0, 0.01) var real_seconds_per_game_minute := 0.7
## Night lasts from this minute of the day (`DayNightModulate` darkens the
## screen around it)...
@export_range(0, 1439) var night_starts_at := 20 * 60
## ...until this one (the next morning when it is the smaller).
@export_range(0, 1439) var night_ends_at := 6 * 60
## The minute the player wakes after sleeping, collapsing or being defeated.
@export_range(0, 1439) var wake_minute := 6 * 60
## The minute a player who is still up collapses and wakes at home; -1 never.
@export_range(-1, 1439) var collapse_minute := 2 * 60

## The running game's calendar (`GameDefinition.current()`).
static func current() -> GameCalendar:
	return GameDefinition.current().get_calendar()

func get_days_per_year() -> int:
	return maxi(season_names.size(), 1) * maxi(days_per_season, 1)

## The season `day` falls in, counted from 0 (day 1 is in the first season).
func get_season_index(day: int) -> int:
	return posmod((maxi(day, 1) - 1) / maxi(days_per_season, 1), maxi(season_names.size(), 1))

## The name of the season `day` falls in ("" for a calendar without seasons).
func get_season_name(day: int) -> String:
	return "" if season_names.is_empty() else season_names[get_season_index(day)]

## The day of its season `day` is, from 1.
func get_day_of_season(day: int) -> int:
	return posmod(maxi(day, 1) - 1, maxi(days_per_season, 1)) + 1

## The year `day` falls in, from 1.
func get_year(day: int) -> int:
	return (maxi(day, 1) - 1) / get_days_per_year() + 1

## The weekday of `day`, from 0 (day 1 is weekday 0).
func get_weekday(day: int) -> int:
	return posmod(maxi(day, 1) - 1, maxi(days_per_week, 1))

func has_season(season: String) -> bool:
	return season_names.has(season)

## The day a player who goes to sleep, collapses or is defeated at
## `minute_of_day` of `day` wakes on: the same day when it is still before the
## wake minute (after midnight), the next day otherwise.
func get_wake_day(day: int, minute_of_day: int) -> int:
	return day if posmod(minute_of_day, GameClock.MINUTES_PER_DAY) < wake_minute else day + 1

## Whether `minute_of_day` is at night.
func is_night(minute_of_day: int) -> bool:
	var minute := posmod(minute_of_day, GameClock.MINUTES_PER_DAY)
	if night_starts_at <= night_ends_at:
		return minute >= night_starts_at and minute < night_ends_at
	return minute >= night_starts_at or minute < night_ends_at

func find_problems() -> PackedStringArray:
	var problems := PackedStringArray()
	if season_names.is_empty():
		problems.append("calendar has no seasons")
	var seen := {}
	for season: String in season_names:
		if season.strip_edges().is_empty():
			problems.append("calendar has a season without a name")
		elif seen.has(season):
			problems.append("calendar lists season '%s' twice" % season)
		seen[season] = true
	if days_per_season < 1 or days_per_week < 1:
		problems.append("calendar seasons and weeks need at least one day")
	if real_seconds_per_game_minute <= 0.0:
		problems.append("calendar game minutes need to last some real time")
	for minute: int in [night_starts_at, night_ends_at, wake_minute]:
		if minute < 0 or minute >= GameClock.MINUTES_PER_DAY:
			problems.append("calendar minute %d is not a minute of the day (0-%d)" % [minute, GameClock.MINUTES_PER_DAY - 1])
	if night_starts_at == night_ends_at:
		problems.append("calendar night starts and ends at the same minute")
	if collapse_minute < -1 or collapse_minute >= GameClock.MINUTES_PER_DAY:
		problems.append("calendar collapse minute %d is neither -1 nor a minute of the day" % collapse_minute)
	elif collapse_minute == wake_minute:
		problems.append("calendar collapses the player at the minute they wake")
	return problems
