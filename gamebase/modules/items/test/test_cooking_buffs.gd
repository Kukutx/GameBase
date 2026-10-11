extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

var _clock_snapshot: Dictionary
var _buff_snapshot: Dictionary

func before_each() -> void:
	_clock_snapshot = WorldClock.to_save_data()
	_buff_snapshot = BuffState.to_save_data()
	WorldClock.set_time(1, 8 * 60)
	ContentFixture.use(self, [
		_buff(&"fixture_focus", 180, {&"fixture_wait": 0.7, &"fixture_window": 1.35}),
		_buff(&"fixture_vigor", 240, {&"fixture_speed": 1.1}),
	])
	BuffState.clear()

func after_each() -> void:
	# GUT frees the fixture content after after_each(): restore the saved state
	# against the game's own content.
	ContentRegistry.active = ContentDB
	WorldClock.load_save_data(_clock_snapshot)
	BuffState.load_save_data(_buff_snapshot)

func test_buff_changes_its_stats_and_round_trips_save_data() -> void:
	assert_true(BuffState.apply_buff(&"fixture_focus"))
	assert_almost_eq(BuffState.get_stat_multiplier(&"fixture_wait"), 0.7, 0.001)
	assert_almost_eq(BuffState.get_stat_multiplier(&"fixture_window"), 1.35, 0.001)
	assert_almost_eq(BuffState.get_stat_multiplier(&"fixture_speed"), 1.0, 0.001, "a stat no active buff changes")
	var saved := BuffState.to_save_data()
	assert_true(saved.has("fixture_focus"))

	BuffState.clear()
	assert_false(BuffState.has_buff(&"fixture_focus"))
	assert_almost_eq(BuffState.get_stat_multiplier(&"fixture_wait"), 1.0, 0.001)
	BuffState.load_save_data(saved)
	assert_true(BuffState.has_buff(&"fixture_focus"))
	assert_eq(BuffState.get_minutes_remaining(&"fixture_focus"), 180)

func test_buff_load_clamps_corrupt_far_future_expiry_to_one_game_day() -> void:
	var now := BuffState.get_absolute_minute()
	BuffState.load_save_data({"fixture_vigor": now + 999999})
	assert_true(BuffState.has_buff(&"fixture_vigor"))
	assert_eq(BuffState.get_minutes_remaining(&"fixture_vigor"), GameClock.MINUTES_PER_DAY)

func test_buffs_expire_by_game_time() -> void:
	assert_true(BuffState.apply_buff(&"fixture_vigor"))
	assert_eq(BuffState.get_minutes_remaining(&"fixture_vigor"), 240)
	WorldClock.set_time(1, 11 * 60 + 59)
	assert_true(BuffState.has_buff(&"fixture_vigor"))
	assert_eq(BuffState.get_minutes_remaining(&"fixture_vigor"), 1)
	WorldClock.set_time(1, 12 * 60)
	assert_false(BuffState.has_buff(&"fixture_vigor"))

func _buff(id: StringName, duration_minutes: int, multipliers: Dictionary) -> FoodBuffData:
	var buff := FoodBuffData.new()
	buff.id = id
	buff.display_name = String(id).capitalize()
	buff.duration_minutes = duration_minutes
	for stat: StringName in multipliers:
		buff.multipliers[stat] = float(multipliers[stat])
	return buff
