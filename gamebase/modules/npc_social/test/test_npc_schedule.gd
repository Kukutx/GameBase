extends GutTest

func test_schedule_selects_latest_entry_before_time() -> void:
	var schedule := NpcSchedule.new()
	add_child_autofree(schedule)
	var morning := NpcScheduleEntry.new()
	morning.minute_of_day = 8 * 60
	morning.activity = "Morning"
	var noon := NpcScheduleEntry.new()
	noon.minute_of_day = 12 * 60
	noon.activity = "Noon"
	schedule.entries = [morning, noon]

	assert_eq(schedule.get_entry_for_minute(10 * 60), morning)
	assert_eq(schedule.get_entry_for_minute(13 * 60), noon)

func test_schedule_wraps_to_previous_day_entry_before_first_slot() -> void:
	var schedule := NpcSchedule.new()
	add_child_autofree(schedule)
	var morning := NpcScheduleEntry.new()
	morning.minute_of_day = 8 * 60
	var evening := NpcScheduleEntry.new()
	evening.minute_of_day = 18 * 60
	schedule.entries = [morning, evening]

	assert_eq(schedule.get_entry_for_minute(5 * 60), evening)

func test_pre_dawn_schedule_uses_previous_day_weekday_route_not_todays_evening() -> void:
	var schedule := NpcSchedule.new()
	add_child_autofree(schedule)
	var sunday_visit := NpcScheduleEntry.new()
	sunday_visit.minute_of_day = 18 * 60
	sunday_visit.location_id = &"fixture_riverside"
	sunday_visit.activity = "Sunday overnight"
	sunday_visit.days_of_week = PackedInt32Array([6])
	var monday_evening := NpcScheduleEntry.new()
	monday_evening.minute_of_day = 18 * 60
	monday_evening.location_id = &"fixture_square"
	monday_evening.activity = "Monday evening"
	monday_evening.days_of_week = PackedInt32Array([0])
	schedule.entries = [sunday_visit, monday_evening]

	# Day 7 is Sunday and Day 8 is Monday. At 05:00 Monday the Sunday route
	# should still define presence until the first Monday route starts.
	assert_eq(schedule.get_entry_for_minute(5 * 60, 8), sunday_visit)

func test_schedule_filters_by_season_and_weekday() -> void:
	var schedule := NpcSchedule.new()
	add_child_autofree(schedule)
	var spring_monday := NpcScheduleEntry.new()
	spring_monday.minute_of_day = 8 * 60
	spring_monday.activity = "Spring Monday"
	spring_monday.seasons = PackedStringArray(["Spring"])
	spring_monday.days_of_week = PackedInt32Array([0])
	var fallback := NpcScheduleEntry.new()
	fallback.minute_of_day = 9 * 60
	fallback.activity = "Fallback"
	schedule.entries = [spring_monday, fallback]

	assert_eq(schedule.get_entry_for_minute(8 * 60 + 30, 1), spring_monday)
	assert_eq(schedule.get_entry_for_minute(8 * 60 + 30, 2), fallback)
	assert_eq(schedule.get_entry_for_minute(8 * 60 + 30, 29), fallback)

func test_schedule_can_depend_on_world_flag() -> void:
	var previous := WorldState.to_save_data()
	var schedule := NpcSchedule.new()
	add_child_autofree(schedule)
	var special := NpcScheduleEntry.new()
	special.minute_of_day = 8 * 60
	special.required_world_flag = &"event:market_open"
	var fallback := NpcScheduleEntry.new()
	fallback.minute_of_day = 9 * 60
	schedule.entries = [special, fallback]

	WorldState.erase(&"event:market_open")
	assert_eq(schedule.get_entry_for_minute(8 * 60 + 30, 1), fallback)
	WorldState.set_value(&"event:market_open", true)
	assert_eq(schedule.get_entry_for_minute(8 * 60 + 30, 1), special)
	WorldState.load_save_data(previous)

func test_schedule_entry_can_target_a_different_location() -> void:
	var schedule := NpcSchedule.new()
	add_child_autofree(schedule)
	schedule.current_location_id = &"fixture_square"
	var entry := NpcScheduleEntry.new()
	entry.location_id = &"fixture_home"
	entry.minute_of_day = 8 * 60
	schedule.entries = [entry]

	assert_false(schedule.is_entry_present_here(entry))
	schedule.current_location_id = &"fixture_home"
	assert_true(schedule.is_entry_present_here(entry))

func test_high_priority_event_schedule_overrides_normal_schedule() -> void:
	var schedule := NpcSchedule.new()
	add_child_autofree(schedule)
	var normal := NpcScheduleEntry.new()
	normal.minute_of_day = 10 * 60
	normal.priority = 0
	normal.activity = "Normal"
	var event_entry := NpcScheduleEntry.new()
	event_entry.minute_of_day = 9 * 60
	event_entry.priority = 10
	event_entry.activity = "Festival"
	schedule.entries = [normal, event_entry]

	assert_eq(schedule.get_entry_for_minute(12 * 60, 1), event_entry)

func test_weather_specific_schedule_overrides_normal_route_on_storm_days() -> void:
	var storm_day := _find_weather_day("Storm")
	var clear_day := _find_weather_day("Clear")
	assert_gt(storm_day, 0)
	assert_gt(clear_day, 0)

	var schedule := NpcSchedule.new()
	add_child_autofree(schedule)
	var normal := NpcScheduleEntry.new()
	normal.minute_of_day = 8 * 60
	normal.activity = "Outdoor work"
	var storm_shelter := NpcScheduleEntry.new()
	storm_shelter.minute_of_day = 0
	storm_shelter.priority = 20
	storm_shelter.activity = "Shelter"
	storm_shelter.allowed_weather = PackedStringArray(["Storm"])
	schedule.entries = [normal, storm_shelter]

	assert_eq(schedule.get_entry_for_minute(10 * 60, storm_day), storm_shelter)
	assert_eq(schedule.get_entry_for_minute(10 * 60, clear_day), normal)

func _find_weather_day(weather_name: String) -> int:
	for day in range(1, 366):
		var name := WeatherState.get_weather_name(WeatherState.get_weather_for_day(day))
		if name == weather_name:
			return day
	return -1
