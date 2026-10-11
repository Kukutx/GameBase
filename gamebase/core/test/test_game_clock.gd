extends GutTest

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

	clock.set_time(1, 5 * 60)
	assert_true(clock.is_night())
	clock.set_time(1, 12 * 60)
	assert_false(clock.is_night())
	clock.set_time(1, 20 * 60)
	assert_true(clock.is_night())

func test_sleep_spot_blocks_day_changed_reentrancy() -> void:
	var clock_snapshot := WorldClock.to_save_data()
	var player_snapshot := PlayerState.to_save_data()
	WorldClock.set_time(10, 22 * 60)
	PlayerState.energy = 1
	PlayerState.health = 1
	var scene := load("res://gamebase/core/player/sleep_spot.tscn") as PackedScene
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
	assert_eq(WorldClock.minute_of_day, 6 * 60)
	assert_eq(PlayerState.energy, PlayerState.max_energy)
	assert_eq(PlayerState.health, PlayerState.max_health)
	WorldClock.load_save_data(clock_snapshot)
	PlayerState.load_save_data(player_snapshot)
