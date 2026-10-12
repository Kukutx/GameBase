extends GutTest

## The calendar's seasons and the weather rolled for each day
## (`GameWeatherSystem`).

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

var _seed: int

func before_each() -> void:
	_seed = GameRandom.world_seed

func after_each() -> void:
	GameRandom.set_seed(_seed)

func test_seasons_roll_every_28_days() -> void:
	ContentFixture.use_calendar(self, GameCalendar.new())
	assert_eq(GameCalendar.current().get_season_name(1), "Spring")
	assert_eq(GameCalendar.current().get_season_name(28), "Spring")
	assert_eq(GameCalendar.current().get_season_name(29), "Summer")
	assert_eq(GameCalendar.current().get_season_name(57), "Autumn")
	assert_eq(GameCalendar.current().get_season_name(85), "Winter")
	assert_eq(GameCalendar.current().get_season_name(113), "Spring")

func test_weather_follows_the_games_odds_for_each_season() -> void:
	var definition := _definition([_odds("Spring", 0.0, 1.0), _odds("Summer", 1.0, 0.0)])
	var days: Array = ContentFixture.with_definition(definition, func() -> Array:
		var weather := _weather()
		return [weather.get_weather_for_day(1), weather.get_weather_for_day(29), weather.get_weather_for_day(57)])
	assert_eq(days, [GameWeatherSystem.Weather.STORM, GameWeatherSystem.Weather.RAIN, GameWeatherSystem.Weather.CLEAR],
		"certain storm in spring, certain rain in summer, no odds in autumn")

func test_the_same_seed_gives_the_same_weather_and_another_seed_other_weather() -> void:
	var definition := _definition([_odds("Spring", 0.5, 0.0)])
	GameRandom.set_seed(12345)
	var first: Array = ContentFixture.with_definition(definition, _spring.bind(_weather()))
	var again: Array = ContentFixture.with_definition(definition, _spring.bind(_weather()))
	assert_eq(first, again)
	GameRandom.set_seed(54321)
	var other: Array = ContentFixture.with_definition(definition, _spring.bind(_weather()))
	assert_ne(first, other)

func test_odds_problems_name_the_season() -> void:
	ContentFixture.use_calendar(self, GameCalendar.new())
	var problems := "\n".join(GameWeatherSystem.find_odds_problems([
		_odds("Spring", 0.2, 0.1), _odds("Monsoon", 0.5, 0.0), _odds("Spring", 0.1, 0.0), _odds("Summer", 0.8, 0.3),
	]))
	assert_string_contains(problems, "unknown season 'Monsoon'")
	assert_string_contains(problems, "list season 'Spring' twice")
	assert_string_contains(problems, "odds of 'Summer' are not chances that add up to at most 1")
	assert_eq(GameWeatherSystem.find_odds_problems([_odds("Winter", 0.5, 0.5)]), PackedStringArray())

func _spring(weather: GameWeatherSystem) -> Array:
	var result: Array = []
	for day: int in range(1, GameCalendar.current().days_per_season + 1):
		result.append(weather.get_weather_for_day(day))
	return result

# A weather service outside the tree: it rolls days without listening to the clock.
func _weather() -> GameWeatherSystem:
	return autofree(GameWeatherSystem.new())

func _definition(odds: Array[WeatherOdds]) -> GameDefinition:
	var definition := GameDefinition.new()
	definition.weather_odds = odds
	return definition

func _odds(season: String, rain: float, storm: float) -> WeatherOdds:
	var odds := WeatherOdds.new()
	odds.season = season
	odds.rain = rain
	odds.storm = storm
	return odds
