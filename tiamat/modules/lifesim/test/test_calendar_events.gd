extends GutTest

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")

func test_calendar_event_filters_day_time_season_and_weekday() -> void:
	var event := CalendarEventData.new()
	event.seasons = PackedStringArray(["Spring"])
	event.day_of_season = 6
	event.days_of_week = PackedInt32Array([5])
	event.start_minute = 9 * 60
	event.end_minute = 16 * 60

	assert_true(event.is_active(6, 10 * 60))
	assert_false(event.is_active(6, 8 * 60))
	assert_false(event.is_active(7, 10 * 60))
	assert_false(event.is_active(34, 10 * 60))

func test_an_event_s_weekdays_follow_the_game_s_week() -> void:
	var calendar := GameCalendar.new()
	calendar.days_per_week = 5
	var definition := GameDefinition.new()
	definition.calendar = calendar
	var event := CalendarEventData.new()
	event.days_of_week = PackedInt32Array([4])
	var active_days: Array = ContentFixture.with_definition(definition, func() -> Array:
		return range(1, 12).filter(func(day: int) -> bool: return event.is_active(day, event.start_minute)))
	assert_eq(active_days, [5, 10], "weekday 4 of a five-day week")
	event.days_of_week = PackedInt32Array([5])
	var problems: PackedStringArray = ContentFixture.with_definition(definition, event.find_problems.bind(ContentDB))
	assert_true(problems.has("has invalid weekday 5"), "\n".join(problems))

func test_the_events_ahead_come_soonest_first_and_one_over_today_waits() -> void:
	ContentFixture.use_calendar(self, GameCalendar.new())
	var fair := _event(&"fixture_fair", 9, 9 * 60)
	var market := _event(&"fixture_market", 6, 9 * 60)
	var dawn := _event(&"fixture_dawn", 6, 6 * 60)
	var weekly := _event(&"fixture_weekly", 0, 10 * 60)
	weekly.days_of_week = PackedInt32Array([1])
	ContentFixture.use(self, [fair, market, dawn, weekly])
	assert_eq(market.next_day(1, 28), 6)
	assert_eq(market.next_day(6, 28, 10 * 60), 6, "on now, it is today's")
	assert_eq(market.next_day(6, 28, 16 * 60), -1, "over for today, and not again this season")
	assert_eq(weekly.next_day(2, 28, 16 * 60), 9, "over for today, it is next week's")
	var upcoming := CalendarEventData.find_upcoming(1, 28)
	assert_eq(upcoming.map(func(entry: Dictionary) -> StringName: return (entry["event"] as CalendarEventData).id),
		[&"fixture_weekly", &"fixture_dawn", &"fixture_market", &"fixture_fair"], "by day, then by the hour each starts")
	assert_eq(upcoming.map(func(entry: Dictionary) -> int: return int(entry["day"])), [2, 6, 6, 9])
	assert_eq(CalendarEventData.find_upcoming(10, 3).size(), 0, "none in the days asked")

static func _event(id: StringName, day_of_season: int, start_minute: int) -> CalendarEventData:
	var event := CalendarEventData.new()
	event.id = id
	event.display_name = String(id)
	event.seasons = PackedStringArray(["Spring"])
	event.day_of_season = day_of_season
	event.start_minute = start_minute
	event.end_minute = 16 * 60
	return event
