extends GutTest

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

func test_accessibility_page_opens_with_controller_focus() -> void:
	var scene := load("res://gamebase/core/ui/settings_menu.tscn") as PackedScene
	var menu := scene.instantiate() as SettingsMenu
	add_child_autofree(menu)
	await get_tree().process_frame
	menu.open()
	menu.show_page(SettingsMenu.Page.ACCESSIBILITY)
	await get_tree().process_frame

	var weather := menu.weather_effects_check
	var motion := menu.reduced_motion_check
	assert_true(menu.accessibility_page.visible)
	assert_eq(get_viewport().gui_get_focus_owner(), weather)
	assert_eq(weather.button_pressed, GameSettings.weather_effects)
	assert_eq(motion.button_pressed, GameSettings.reduced_motion)
	menu.close()
