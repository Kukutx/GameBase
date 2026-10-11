extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

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
