extends GutTest

## The game's calendar (`GameCalendar`), and the clock and time conditions that
## count by it.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

func test_the_default_calendar_has_four_seasons_of_28_days() -> void:
	var calendar := GameCalendar.new()
	assert_eq(calendar.get_season_name(1), "Spring")
	assert_eq(calendar.get_season_name(29), "Summer")
	assert_eq(calendar.get_day_of_season(29), 1)
	assert_eq(calendar.get_year(112), 1)
	assert_eq(calendar.get_year(113), 2)
	assert_eq(calendar.get_season_name(113), "Spring")
	assert_eq(calendar.get_weekday(8), 0)
	assert_true(calendar.is_night(5 * 60))
	assert_false(calendar.is_night(12 * 60))
	assert_true(calendar.is_night(20 * 60))
	assert_eq(calendar.find_problems(), PackedStringArray())

func test_a_game_counts_its_days_by_its_own_calendar() -> void:
	var calendar := _calendar(PackedStringArray(["Dry", "Wet"]), 10, 5)
	# Day 23: the third day of the second year's dry season, weekday 2.
	assert_eq(calendar.get_season_name(23), "Dry")
	assert_eq(calendar.get_day_of_season(23), 3)
	assert_eq(calendar.get_year(23), 2)
	assert_eq(calendar.get_weekday(23), 2)
	assert_eq(calendar.get_season_name(15), "Wet")
	var held: bool = ContentFixture.with_definition(_definition(calendar), GameRules.check.bind("SEASON Dry, DAY_OF_SEASON 3, WEEKDAY 2", {"day": 23}))
	assert_true(held, "the time conditions read the game's calendar")

func test_the_date_reads_by_the_calendar() -> void:
	var previous := TranslationServer.get_locale()
	TranslationServer.set_locale("en")
	var seasons := _calendar(PackedStringArray(["Dry", "Wet"]), 10, 5)
	assert_eq(seasons.get_date_text(13), "Wet 3")
	assert_eq(seasons.get_date_text(23), "Dry 3, Year 2", "the year shows from the second on")
	var one_season := _calendar(PackedStringArray(["Run"]), 1000, 7)
	assert_eq(one_season.get_date_text(31), "Day 31", "a calendar of one season counts the days alone")
	TranslationServer.set_locale("zh_CN")
	assert_eq(seasons.get_date_text(23), "Dry3日（第2年）")
	assert_eq(one_season.get_date_text(31), "第31天")
	TranslationServer.set_locale(previous)

func test_time_conditions_name_only_what_the_calendar_has() -> void:
	var definition := _definition(_calendar(PackedStringArray(["Dry", "Wet"]), 10, 5))
	var problems := "\n".join(ContentFixture.with_definition(definition, GameRules.validate_query.bind("SEASON Spring, DAY_OF_SEASON 11, WEEKDAY 5")))
	assert_string_contains(problems, "unknown season 'Spring'")
	assert_string_contains(problems, "11 is not a day of a season (1-10)")
	assert_string_contains(problems, "5 is not a weekday (0-4)")
	var fine: PackedStringArray = ContentFixture.with_definition(definition, GameRules.validate_query.bind("SEASON Wet, DAY_OF_SEASON 10, WEEKDAY 0 4"))
	assert_eq(fine, PackedStringArray())

func test_night_can_fall_within_one_day() -> void:
	var calendar := GameCalendar.new()
	calendar.night_starts_at = 60
	calendar.night_ends_at = 5 * 60
	assert_false(calendar.is_night(0))
	assert_true(calendar.is_night(60))
	assert_false(calendar.is_night(5 * 60))

func test_the_clock_runs_on_until_a_condition_holds() -> void:
	var clock := _clock(1, 10 * 60)
	watch_signals(clock)
	assert_eq(clock.advance_until("TIME_BETWEEN 1080 1440", 3 * GameClock.MINUTES_PER_DAY), 8 * 60)
	assert_eq(clock.minute_of_day, 18 * 60)
	assert_eq(clock.advance_until("DAY_OF_SEASON 3, TIME_BETWEEN 420 480", 3 * GameClock.MINUTES_PER_DAY), 6 * 60 + GameClock.MINUTES_PER_DAY + 7 * 60)
	assert_eq([clock.day, clock.minute_of_day], [3, 7 * 60])
	assert_signal_emit_count(clock, "day_changed", 2, "each day passed on the way")
	assert_eq(clock.advance_until("DAY_OF_SEASON 3", 60), 0, "a condition that holds already waits for nothing")

func test_the_clock_stops_at_the_limit_when_the_condition_never_holds() -> void:
	var clock := _clock(1, 10 * 60)
	assert_eq(clock.advance_until("FALSE", 90), -1)
	assert_eq([clock.day, clock.minute_of_day], [1, 11 * 60 + 30])

func test_a_wait_with_a_condition_that_is_no_query_moves_nothing() -> void:
	var clock := _clock(1, 10 * 60)
	assert_eq(clock.advance_until("TIME_BETWEN 1080 1440", 7 * GameClock.MINUTES_PER_DAY), -1)
	assert_eq(clock.advance_until("EVENT_ARG crop turnip", 7 * GameClock.MINUTES_PER_DAY), -1)
	assert_eq([clock.day, clock.minute_of_day], [1, 10 * 60])

func test_a_wait_ends_where_a_player_who_is_up_collapses() -> void:
	var clock := _clock(1, 18 * 60)
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child_autofree(player)
	var definition := _definition(GameCalendar.new())
	var collapse_minute := definition.calendar.collapse_minute
	var wait := clock.advance_until.bind("DAY_OF_SEASON 3", 3 * GameClock.MINUTES_PER_DAY)
	assert_eq(ContentFixture.with_definition(definition, wait), -1)
	assert_eq([clock.day, clock.minute_of_day], [2, collapse_minute], "the collapse ends the wait")
	player.remove_from_group(&"player")
	assert_eq(ContentFixture.with_definition(definition, wait), GameClock.MINUTES_PER_DAY - collapse_minute, "nobody is up to collapse")

func test_a_wait_for_the_collapse_minute_ends_in_the_collapse() -> void:
	var clock := _clock(1, 0)
	var player := Node2D.new()
	player.add_to_group(&"player")
	add_child_autofree(player)
	var definition := _definition(GameCalendar.new())
	var collapse_minute := definition.calendar.collapse_minute
	var wait := clock.advance_until.bind("TIME_BETWEEN %d %d" % [collapse_minute, collapse_minute + 60], 3 * 60)
	assert_eq(ContentFixture.with_definition(definition, wait), -1, "the player collapses before they can act")
	assert_eq([clock.day, clock.minute_of_day], [1, collapse_minute])
	player.remove_from_group(&"player")
	clock.set_time(1, 0)
	assert_eq(ContentFixture.with_definition(definition, wait), collapse_minute, "nobody is up to collapse")

func test_a_player_wakes_the_same_day_after_midnight_and_the_next_day_before_it() -> void:
	var calendar := GameCalendar.new()
	assert_eq(calendar.get_wake_day(5, 22 * 60), 6)
	assert_eq(calendar.get_wake_day(5, 3 * 60), 5, "still the night before day 5's morning")
	assert_eq(calendar.get_wake_day(5, calendar.wake_minute), 6)

func test_the_screen_darkens_by_the_calendar_s_night() -> void:
	var tint := DayNightModulate.new()
	var farm_night: Array = ContentFixture.with_definition(_definition(GameCalendar.new()), func() -> Array:
		return [5 * 60, 6 * 60, 7 * 60, 8 * 60, 12 * 60, 18 * 60, 20 * 60, 21 * 60, 0].map(tint.color_for_minute))
	# The default calendar's night, 20:00 to 06:00: full night until 05:00,
	# dawn at 07:00, day from 09:00 to 17:00, dusk at 19:00, night from 21:00.
	var expected := [tint.night_color, tint.night_color.lerp(tint.dawn_color, 0.5), tint.dawn_color,
		tint.dawn_color.lerp(tint.day_color, 0.5), tint.day_color, tint.day_color.lerp(tint.dusk_color, 0.5),
		tint.dusk_color.lerp(tint.night_color, 0.5), tint.night_color, tint.night_color]
	for index: int in expected.size():
		assert_true((farm_night[index] as Color).is_equal_approx(expected[index]), "%s at sample %d" % [farm_night[index], index])
	var calendar := GameCalendar.new()
	calendar.night_starts_at = 18 * 60
	var early: Color = ContentFixture.with_definition(_definition(calendar), tint.color_for_minute.bind(19 * 60))
	assert_true(early.is_equal_approx(tint.night_color), "a game whose night falls at 18:00 is dark at 19:00")
	tint.free()

func test_a_calendar_whose_minutes_last_no_time_stops_the_clock() -> void:
	var calendar := GameCalendar.new()
	calendar.real_seconds_per_game_minute = 0.0
	assert_eq(calendar.find_problems(), PackedStringArray())
	var clock := _clock(1, 10 * 60)
	clock.paused = false
	ContentFixture.with_definition(_definition(calendar), clock._process.bind(30.0))
	assert_eq(clock.minute_of_day, 10 * 60, "real time moves it no minute")
	clock.advance_minutes(5)
	assert_eq(clock.minute_of_day, 10 * 60 + 5, "the game still runs it on")

func test_calendar_problems_are_named() -> void:
	var calendar := _calendar(PackedStringArray(["Dry", "Dry", ""]), 0, 5)
	calendar.real_seconds_per_game_minute = -1.0
	calendar.collapse_minute = calendar.wake_minute
	calendar.night_ends_at = calendar.night_starts_at
	var problems := "\n".join(calendar.find_problems())
	assert_string_contains(problems, "calendar lists season 'Dry' twice")
	assert_string_contains(problems, "calendar has a season without a name")
	assert_string_contains(problems, "calendar seasons and weeks need at least one day")
	assert_string_contains(problems, "calendar game minutes cannot last a negative time")
	assert_string_contains(problems, "calendar collapses the player at the minute they wake")
	assert_string_contains(problems, "calendar night starts and ends at the same minute")
	assert_eq(_calendar(PackedStringArray(), 10, 5).find_problems(), PackedStringArray(["calendar has no seasons"]))

func test_season_checks_of_content_follow_the_calendar() -> void:
	var odds := WeatherOdds.new()
	odds.season = "Spring"
	var all_odds: Array[WeatherOdds] = [odds]
	var definition := _definition(_calendar(PackedStringArray(["Dry", "Wet"]), 10, 5))
	var problems: PackedStringArray = ContentFixture.with_definition(definition, GameWeatherSystem.find_odds_problems.bind(all_odds))
	assert_string_contains("\n".join(problems), "unknown season 'Spring'")

func _calendar(seasons: PackedStringArray, days_per_season: int, days_per_week: int) -> GameCalendar:
	var calendar := GameCalendar.new()
	calendar.season_names = seasons
	calendar.days_per_season = days_per_season
	calendar.days_per_week = days_per_week
	return calendar

func _definition(calendar: GameCalendar) -> GameDefinition:
	var definition := GameDefinition.new()
	definition.calendar = calendar
	return definition

# A clock of its own, stopped: it moves only when the test runs it on.
func _clock(day: int, minute_of_day: int) -> GameClock:
	var clock := GameClock.new()
	clock.paused = true
	add_child_autofree(clock)
	clock.set_time(day, minute_of_day)
	return clock
