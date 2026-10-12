extends GutTest

## The weather over an outdoor location (`WeatherOverlay`): it shows what the
## day's `WeatherData` asks for and follows the weather effects and reduced
## motion settings as they change.

var _weather_effects_before := true
var _reduced_motion_before := false

func before_each() -> void:
	_weather_effects_before = GameSettings.weather_effects
	_reduced_motion_before = GameSettings.reduced_motion

func after_each() -> void:
	GameSettings.weather_effects = _weather_effects_before
	GameSettings.reduced_motion = _reduced_motion_before
	GameSettings.changed.emit()

func test_weather_effects_and_reduced_motion_apply_live() -> void:
	GameSettings.weather_effects = true
	GameSettings.reduced_motion = false
	var overlay := WeatherOverlay.new()
	add_child_autofree(overlay)
	await get_tree().process_frame
	overlay.set("_weather_exposed", true)
	var rain := WeatherData.new()
	rain.particle = WeatherData.Particle.RAIN
	overlay.call("_set_weather", rain)
	assert_true(overlay.visible)
	assert_true(overlay.is_processing())

	GameSettings.reduced_motion = true
	GameSettings.changed.emit()
	assert_true(overlay.visible)
	assert_false(overlay.is_processing())

	GameSettings.weather_effects = false
	GameSettings.changed.emit()
	assert_false(overlay.visible)
	assert_false(overlay.is_processing())

func test_it_shows_nothing_for_weather_without_effects_and_draws_each_kind() -> void:
	GameSettings.weather_effects = true
	GameSettings.reduced_motion = false
	var overlay := WeatherOverlay.new()
	overlay.size = Vector2(64, 48)
	add_child_autofree(overlay)
	await get_tree().process_frame
	overlay.set("_weather_exposed", true)
	overlay.call("_set_weather", WeatherData.new())
	assert_false(overlay.visible, "clear skies show nothing")
	overlay.call("_set_weather", null)
	assert_false(overlay.visible, "a game without weather shows nothing")
	for particle: int in [WeatherData.Particle.RAIN, WeatherData.Particle.SNOW]:
		var weather := WeatherData.new()
		weather.particle = particle
		weather.lightning = true
		weather.tint = Color(0.1, 0.1, 0.2, 0.2)
		overlay.call("_set_weather", weather)
		assert_true(overlay.visible)
		overlay.queue_redraw()
		await get_tree().process_frame
