extends GutTest

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")

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

func test_schedule_weekdays_follow_the_game_s_week() -> void:
	var calendar := GameCalendar.new()
	calendar.days_per_week = 5
	var definition := GameDefinition.new()
	definition.calendar = calendar
	var market := NpcScheduleEntry.new()
	market.days_of_week = PackedInt32Array([4])
	var days: Array = ContentFixture.with_definition(definition, func() -> Array:
		return range(1, 12).filter(func(day: int) -> bool: return market.matches(day, market.minute_of_day)))
	assert_eq(days, [5, 10], "weekday 4 of a five-day week")

func test_schedule_entries_follow_their_condition() -> void:
	var previous := WorldState.to_save_data()
	var schedule := NpcSchedule.new()
	add_child_autofree(schedule)
	var special := NpcScheduleEntry.new()
	special.minute_of_day = 8 * 60
	special.condition = "WORLD_FLAG fixture_market_open"
	var fallback := NpcScheduleEntry.new()
	fallback.minute_of_day = 9 * 60
	schedule.entries = [special, fallback]

	WorldState.erase(&"fixture_market_open")
	assert_eq(schedule.get_entry_for_minute(8 * 60 + 30, 1), fallback)
	WorldState.set_value(&"fixture_market_open", true)
	assert_eq(schedule.get_entry_for_minute(8 * 60 + 30, 1), special)
	WorldState.load_save_data(previous)

func test_schedule_conditions_are_asked_about_the_minute_looked_up() -> void:
	var schedule := NpcSchedule.new()
	add_child_autofree(schedule)
	var morning_errand := NpcScheduleEntry.new()
	morning_errand.minute_of_day = 8 * 60
	morning_errand.priority = 10
	morning_errand.condition = "TIME_BETWEEN 480 600"
	var day_route := NpcScheduleEntry.new()
	day_route.minute_of_day = 7 * 60
	schedule.entries = [morning_errand, day_route]
	assert_eq(schedule.get_entry_for_minute(9 * 60, 1), morning_errand)
	assert_eq(schedule.get_entry_for_minute(11 * 60, 1), day_route, "the errand's condition no longer holds at 11:00")

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

func test_weather_specific_schedule_overrides_normal_route_on_its_weather() -> void:
	# A storm every day of spring and clear weather in summer, whatever
	# weather the game has.
	ContentFixture.use(self, ContentFixture.weathers([&"fixture_storm"]))
	ContentFixture.use_calendar(self, GameCalendar.new())
	ContentFixture.use_weather(self, {"Spring": {&"fixture_storm": 1.0}})
	var storm_day := 1
	var storm := WeatherState.get_weather_id(storm_day)
	assert_eq(storm, &"fixture_storm")
	var clear_day := 29
	assert_eq(WeatherState.get_weather_id(clear_day), ContentFixture.CLEAR_WEATHER)

	var schedule := NpcSchedule.new()
	add_child_autofree(schedule)
	var normal := NpcScheduleEntry.new()
	normal.minute_of_day = 8 * 60
	normal.activity = "Outdoor work"
	var storm_shelter := NpcScheduleEntry.new()
	storm_shelter.minute_of_day = 0
	storm_shelter.priority = 20
	storm_shelter.activity = "Shelter"
	storm_shelter.allowed_weather.assign([storm])
	schedule.entries = [normal, storm_shelter]

	assert_eq(schedule.get_entry_for_minute(10 * 60, storm_day), storm_shelter)
	assert_eq(schedule.get_entry_for_minute(10 * 60, clear_day), normal)

func test_a_villagers_doings_show_while_the_player_stands_at_them() -> void:
	var npc := GameNpc.new()
	npc.display_name = "Fixture"
	var parts: Dictionary[String, Node] = {"NameLabel": Label.new(), "ActivityLabel": Label.new(), "Interactable": Interactable.new(), "Schedule": NpcSchedule.new()}
	for part_name: String in parts:
		parts[part_name].name = part_name
		npc.add_child(parts[part_name])
	add_child_autofree(npc)
	assert_eq(npc.label.text, "Fixture")
	assert_false(npc.activity_label.visible, "a villager afar shows their name alone")
	npc.interactable.set_focused(true)
	assert_true(npc.activity_label.visible, "the player at them reads what they do")
	assert_string_contains(npc.activity_label.text, "0 hearts")
	npc.interactable.set_focused(false)
	assert_false(npc.activity_label.visible)
	npc.activity_shown_near = false
	npc.call("_show_activity", false)
	assert_true(npc.activity_label.visible, "a game that wants them always shows them")
