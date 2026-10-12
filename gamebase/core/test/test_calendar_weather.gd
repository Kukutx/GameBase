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
	ContentFixture.use(self, _weathers())
	var definition := _definition([_odds("Spring", {&"fixture_storm": 1.0}), _odds("Summer", {&"fixture_storm": 0.0, &"fixture_rain": 1.0})])
	var days: Array = ContentFixture.with_definition(definition, func() -> Array:
		var weather := _weather()
		return [weather.get_weather_id(1), weather.get_weather_id(29), weather.get_weather_id(57), weather.get(&"_by_day").size()])
	assert_eq(days, [&"fixture_storm", &"fixture_rain", &"fixture_clear", 3], "certain storm in spring, certain rain in summer, no odds in autumn")

func test_the_chances_are_rolled_in_their_order() -> void:
	ContentFixture.use(self, _weathers())
	GameRandom.set_seed(12345)
	var storm_first := _definition([_odds("Spring", {&"fixture_storm": 0.3, &"fixture_rain": 0.3})])
	var rain_first := _definition([_odds("Spring", {&"fixture_rain": 0.3, &"fixture_storm": 0.3})])
	var by_storm_first: Array = ContentFixture.with_definition(storm_first, _spring.bind(_weather()))
	var by_rain_first: Array = ContentFixture.with_definition(rain_first, _spring.bind(_weather()))
	for day: int in by_storm_first.size():
		var swapped := {&"fixture_storm": &"fixture_rain", &"fixture_rain": &"fixture_storm", &"fixture_clear": &"fixture_clear"}
		assert_eq(by_rain_first[day], swapped[by_storm_first[day]], "the same roll falls to the other weather")

func test_a_days_weather_tells_its_name_and_whether_it_waters_the_ground() -> void:
	ContentFixture.use(self, _weathers())
	var definition := _definition([_odds("Spring", {&"fixture_rain": 1.0})])
	var told: Array = ContentFixture.with_definition(definition, func() -> Array:
		var weather := _weather()
		return [weather.get_weather_name(1), weather.is_ground_wet(1), weather.get_weather_name(29), weather.is_ground_wet(29), weather.get_weather(29).id])
	assert_eq(told, ["Rain", true, "Clear", false, &"fixture_clear"])

func test_a_game_without_weather_has_none() -> void:
	ContentFixture.use(self, [])
	var told: Array = ContentFixture.with_definition(GameDefinition.new(), func() -> Array:
		var weather := _weather()
		return [GameWeatherSystem.has_weather(), weather.get_weather_id(1), weather.get_weather(1), weather.get_weather_name(1), weather.is_ground_wet(1)])
	assert_eq(told, [false, &"", null, "", false])

func test_the_same_seed_gives_the_same_weather_and_another_seed_other_weather() -> void:
	ContentFixture.use(self, _weathers())
	var definition := _definition([_odds("Spring", {&"fixture_rain": 0.5})])
	GameRandom.set_seed(12345)
	var first: Array = ContentFixture.with_definition(definition, _spring.bind(_weather()))
	var again: Array = ContentFixture.with_definition(definition, _spring.bind(_weather()))
	assert_eq(first, again)
	GameRandom.set_seed(54321)
	var other: Array = ContentFixture.with_definition(definition, _spring.bind(_weather()))
	assert_ne(first, other)

func test_weather_problems_name_the_season_and_the_weather() -> void:
	var registry := ContentFixture.use(self, _weathers())
	ContentFixture.use_calendar(self, GameCalendar.new())
	var definition := _definition([
		_odds("Spring", {&"fixture_rain": 0.2, &"fixture_storm": 0.1}), _odds("Monsoon", {&"fixture_rain": 0.5}), _odds("Spring", {&"fixture_rain": 0.1}),
		_odds("Summer", {&"fixture_rain": 0.8, &"fixture_storm": 0.3}), _odds("Autumn", {&"hail": 0.1, &"fixture_rain": -0.1}),
	])
	var problems := "\n".join(GameWeatherSystem.find_problems(definition, registry))
	assert_string_contains(problems, "unknown season 'Monsoon'")
	assert_string_contains(problems, "list season 'Spring' twice")
	assert_string_contains(problems, "odds of 'Summer' are not chances that add up to at most 1")
	assert_string_contains(problems, "odds of 'Autumn' name unknown weather 'hail'")
	assert_string_contains(problems, "odds of 'Autumn' are not chances")
	assert_eq(GameWeatherSystem.find_problems(_definition([_odds("Winter", {&"fixture_rain": 0.5, &"fixture_storm": 0.5})]), registry), PackedStringArray())
	definition = _definition([_odds("Winter", {&"fixture_rain": 0.5})])
	definition.clear_weather_id = &""
	assert_eq(GameWeatherSystem.find_problems(definition, registry), PackedStringArray(["the game rolls weather but names no clear weather"]))
	definition.clear_weather_id = &"fog"
	assert_eq(GameWeatherSystem.find_problems(definition, registry), PackedStringArray(["the game's clear weather 'fog' is no weather"]))
	assert_eq(GameWeatherSystem.find_problems(GameDefinition.new(), registry), PackedStringArray(), "a game without weather")
	var nameless := WeatherData.new()
	nameless.id = &"fixture_nameless"
	assert_eq(registry.find_entry_problems(nameless), PackedStringArray(["weather 'fixture_nameless' has no display name"]))

func _spring(weather: GameWeatherSystem) -> Array:
	var result: Array = []
	for day: int in range(1, GameCalendar.current().days_per_season + 1):
		result.append(weather.get_weather_id(day))
	return result

# A weather service outside the tree: it rolls days without listening to the clock.
func _weather() -> GameWeatherSystem:
	return autofree(GameWeatherSystem.new())

func _definition(odds: Array[WeatherOdds]) -> GameDefinition:
	var definition := GameDefinition.new()
	definition.weather_odds = odds
	definition.clear_weather_id = &"fixture_clear"
	return definition

func _odds(season: String, chances: Dictionary) -> WeatherOdds:
	var odds := WeatherOdds.new()
	odds.season = season
	odds.chances.assign(chances)
	return odds

func _weathers() -> Array:
	var result: Array = []
	for entry: Array in [[&"fixture_clear", "Clear", false], [&"fixture_rain", "Rain", true], [&"fixture_storm", "Storm", true]]:
		var weather := WeatherData.new()
		weather.id = entry[0]
		weather.display_name = entry[1]
		weather.wets_ground = entry[2]
		result.append(weather)
	return result
