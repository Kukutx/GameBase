extends GutTest

func test_seasons_roll_every_28_days() -> void:
	assert_eq(GameClock.get_season_name_for_day(1), "Spring")
	assert_eq(GameClock.get_season_name_for_day(28), "Spring")
	assert_eq(GameClock.get_season_name_for_day(29), "Summer")
	assert_eq(GameClock.get_season_name_for_day(57), "Autumn")
	assert_eq(GameClock.get_season_name_for_day(85), "Winter")
	assert_eq(GameClock.get_season_name_for_day(113), "Spring")

func test_weather_is_deterministic_for_seed_and_day() -> void:
	var weather := GameWeatherSystem.new()
	weather.world_seed = 12345
	add_child_autofree(weather)
	var first := weather.get_weather_for_day(17)
	var second := weather.get_weather_for_day(17)
	assert_eq(first, second)
