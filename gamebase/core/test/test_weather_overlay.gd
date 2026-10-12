extends GutTest

## The rain and storm over an outdoor location (`WeatherOverlay`): it follows
## the weather effects and reduced motion settings as they change.

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
	overlay.call("_set_weather", GameWeatherSystem.Weather.RAIN)
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
