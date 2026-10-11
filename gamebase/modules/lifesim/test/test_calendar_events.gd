extends GutTest

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
