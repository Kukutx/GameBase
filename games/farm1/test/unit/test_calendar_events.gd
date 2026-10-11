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

func test_content_database_resolves_location_from_scene() -> void:
	var town := ContentDB.get_location_for_scene("res://game/world/dev_world.tscn")
	var home := ContentDB.get_location_for_scene("res://game/world/home_interior.tscn")

	assert_not_null(town)
	assert_eq(town.id, &"starter_town")
	assert_not_null(home)
	assert_eq(home.id, &"player_home")
