extends GutTest

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")

func test_clock_wraps_to_next_day() -> void:
	var clock := GameClock.new()
	clock.paused = true
	add_child_autofree(clock)
	clock.set_time(1, GameClock.MINUTES_PER_DAY - 1)

	clock.advance_minutes(1)

	assert_eq(clock.day, 2)
	assert_eq(clock.minute_of_day, 0)
	assert_eq(clock.get_time_text(), "Day 2  00:00")

func test_night_boundaries() -> void:
	var clock := GameClock.new()
	clock.paused = true
	add_child_autofree(clock)

	# The running game's calendar decides when night falls.
	var calendar := GameCalendar.current()
	clock.set_time(1, posmod(calendar.night_ends_at - 1, GameClock.MINUTES_PER_DAY))
	assert_true(clock.is_night())
	clock.set_time(1, calendar.night_ends_at)
	assert_false(clock.is_night())
	clock.set_time(1, posmod(calendar.night_starts_at - 1, GameClock.MINUTES_PER_DAY))
	assert_false(clock.is_night())
	clock.set_time(1, calendar.night_starts_at)
	assert_true(clock.is_night())

func test_sleep_spot_blocks_day_changed_reentrancy() -> void:
	var clock_snapshot := WorldClock.to_save_data()
	var vitals_snapshot := Vitals.to_save_data()
	var rest := VitalData.new()
	rest.id = &"fixture_rest"
	rest.display_name = "Rest"
	var focus := VitalData.new()
	focus.id = &"fixture_focus"
	focus.display_name = "Focus"
	focus.refill_on_sleep = false
	ContentFixture.use(self, [rest, focus])
	Vitals.reset_new_game()
	WorldClock.set_time(10, 22 * 60)
	Vitals.set_value(rest.id, 1)
	Vitals.set_value(focus.id, 1)
	var scene := load("res://tiamat/core/player/sleep_spot.tscn") as PackedScene
	var sleep_spot := scene.instantiate() as SleepSpot
	add_child_autofree(sleep_spot)
	await get_tree().process_frame
	var observed := {"entered": false}
	var listener := func(_day: int) -> void:
		if bool(observed["entered"]):
			return
		observed["entered"] = true
		sleep_spot.get_node("Interactable").interact(null)
	WorldClock.day_changed.connect(listener)
	sleep_spot.get_node("Interactable").interact(null)
	if WorldClock.day_changed.is_connected(listener):
		WorldClock.day_changed.disconnect(listener)
	assert_true(bool(observed["entered"]))
	assert_eq(WorldClock.day, 11)
	assert_eq(WorldClock.minute_of_day, GameCalendar.current().wake_minute)
	assert_true(Vitals.is_full(rest.id), "sleep refills what it refills")
	assert_eq(Vitals.get_value(focus.id), 1, "and nothing else")
	ContentRegistry.active = ContentDB
	WorldClock.load_save_data(clock_snapshot)
	Vitals.load_save_data(vitals_snapshot)

func test_an_absolute_minute_orders_every_moment_of_the_world() -> void:
	assert_eq(GameClock.absolute_minute(1, 0), 0)
	assert_eq(GameClock.absolute_minute(2, 30), GameClock.MINUTES_PER_DAY + 30)
	assert_eq(GameClock.absolute_minute(0, -5), 0, "out of range reads as the first moment")
	var clock_snapshot := WorldClock.to_save_data()
	WorldClock.set_time(3, 90)
	assert_eq(WorldClock.get_absolute_minute(), 2 * GameClock.MINUTES_PER_DAY + 90, "the clock's own moment")
	WorldClock.load_save_data(clock_snapshot)

func test_a_run_of_minutes_says_so_and_ends_with_one_word() -> void:
	var clock := GameClock.new()
	clock.paused = true
	add_child_autofree(clock)
	var seen := {"running": 0, "standing": 0, "advanced": 0}
	clock.minute_changed.connect(func(_day: int, _minute: int) -> void:
		var key := "running" if clock.is_advancing() else "standing"
		seen[key] = int(seen[key]) + 1)
	clock.advanced.connect(func() -> void: seen["advanced"] = int(seen["advanced"]) + 1)
	clock.advance_minutes(90)
	assert_eq(seen["running"], 90, "every minute of the run passes, and says it runs")
	assert_eq(seen["advanced"], 1, "the run ends with one word")
	assert_false(clock.is_advancing())
	assert_eq(clock.advance_until("FALSE", 30), -1)
	assert_eq(seen["running"], 120, "a wait runs as well")
	assert_eq(seen["advanced"], 2)
	clock.set_time(2, 600)
	assert_eq(seen["standing"], 1, "a jump is no run")
	assert_eq(seen["advanced"], 2)
