class_name WeatherOverlay
extends Control

@export_range(8, 160, 1) var rain_streaks := 72
@export_range(20.0, 1000.0, 1.0) var fall_speed := 360.0

var _phase := 0.0
var _weather := GameWeatherSystem.Weather.CLEAR
var _weather_exposed := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	WeatherState.weather_changed.connect(_on_weather_changed)
	_refresh_location_exposure()
	_set_weather(WeatherState.current_weather)

func _process(delta: float) -> void:
	if not visible:
		return
	_phase = fmod(_phase + delta, 10000.0)
	queue_redraw()

func refresh_location() -> void:
	_refresh_location_exposure()
	_set_weather(WeatherState.current_weather)

func _on_weather_changed(_day: int, weather: GameWeatherSystem.Weather) -> void:
	_set_weather(weather)

func _set_weather(weather: GameWeatherSystem.Weather) -> void:
	_weather = weather
	visible = _weather_exposed and (_weather == GameWeatherSystem.Weather.RAIN or _weather == GameWeatherSystem.Weather.STORM)
	set_process(visible)
	queue_redraw()

func _refresh_location_exposure() -> void:
	var location := ContentDB.get_current_location(get_tree())
	_weather_exposed = location == null or location.weather_exposed

func _draw() -> void:
	if not visible:
		return
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size
	var storm := _weather == GameWeatherSystem.Weather.STORM
	var tint := Color(0.10, 0.16, 0.24, 0.10 if not storm else 0.17)
	draw_rect(Rect2(Vector2.ZERO, viewport_size), tint)

	var count := rain_streaks + (24 if storm else 0)
	var speed := fall_speed * (1.3 if storm else 1.0)
	var slant := 7.0 if storm else 4.0
	var streak_length := 15.0 if storm else 11.0
	var rain_color := Color(0.72, 0.84, 1.0, 0.48 if storm else 0.36)
	for index in range(count):
		var x := fposmod(float(index * 71) + _phase * speed * 0.34, viewport_size.x + 64.0) - 32.0
		var y := fposmod(float(index * 43) + _phase * speed, viewport_size.y + 48.0) - 24.0
		draw_line(Vector2(x, y), Vector2(x - slant, y + streak_length), rain_color, 1.0)

	if storm:
		var pulse := maxf(sin(_phase * 0.72) - 0.94, 0.0) / 0.06
		if pulse > 0.0:
			draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.85, 0.90, 1.0, clampf(pulse * 0.12, 0.0, 0.12)))
