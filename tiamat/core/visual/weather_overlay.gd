class_name WeatherOverlay
extends Control

## Shows the day's weather (`WeatherData`) over the view: its tint, what falls
## from the sky and its lightning. It shows nothing indoors (a location that
## is not `weather_exposed`), with the weather effects setting off, or for
## weather that shows nothing; with reduced motion only the tint stays.

## Streaks or flakes of a weather of density 1.
@export_range(8, 160, 1) var particles := 72
## Pixels a second rain of fall speed 1 falls.
@export_range(20.0, 1000.0, 1.0) var fall_speed := 360.0

var _phase := 0.0
var _weather: WeatherData
var _weather_exposed := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	WeatherState.weather_changed.connect(_on_weather_changed)
	GameSettings.changed.connect(_on_settings_changed)
	_refresh_location_exposure()
	_set_weather(WeatherState.get_weather())

func _process(delta: float) -> void:
	if not visible:
		return
	_phase = fmod(_phase + delta, 10000.0)
	queue_redraw()

func refresh_location() -> void:
	_refresh_location_exposure()
	_set_weather(WeatherState.get_weather())

func _on_weather_changed(_day: int, weather_id: StringName) -> void:
	_set_weather(WeatherData.find(weather_id) if weather_id != &"" else null)

func _set_weather(weather: WeatherData) -> void:
	_weather = weather
	visible = GameSettings.weather_effects and _weather_exposed and weather != null and weather.shows_effects()
	set_process(visible and not GameSettings.reduced_motion)
	queue_redraw()

func _on_settings_changed() -> void:
	_set_weather(_weather)

func _refresh_location_exposure() -> void:
	var location := WorldLocationData.find_current(get_tree())
	_weather_exposed = location == null or location.weather_exposed

func _draw() -> void:
	if not visible:
		return
	var viewport_size := size
	if viewport_size.x <= 0.0 or viewport_size.y <= 0.0:
		viewport_size = get_viewport_rect().size
	if _weather.tint.a > 0.0:
		draw_rect(Rect2(Vector2.ZERO, viewport_size), _weather.tint)
	if GameSettings.reduced_motion:
		return
	match _weather.particle:
		WeatherData.Particle.RAIN:
			_draw_rain(viewport_size)
		WeatherData.Particle.SNOW:
			_draw_snow(viewport_size)
	if _weather.lightning:
		var pulse := maxf(sin(_phase * 0.72) - 0.94, 0.0) / 0.06
		if pulse > 0.0:
			draw_rect(Rect2(Vector2.ZERO, viewport_size), Color(0.85, 0.90, 1.0, clampf(pulse * 0.12, 0.0, 0.12)))

func _draw_rain(viewport_size: Vector2) -> void:
	var speed := fall_speed * _weather.fall_speed
	var streak_length := 11.0 * _weather.fall_speed
	for index: int in _particle_count():
		var x := fposmod(float(index * 71) + _phase * speed * 0.34, viewport_size.x + 64.0) - 32.0
		var y := fposmod(float(index * 43) + _phase * speed, viewport_size.y + 48.0) - 24.0
		draw_line(Vector2(x, y), Vector2(x - _weather.wind, y + streak_length), _weather.particle_color, 1.0)

func _draw_snow(viewport_size: Vector2) -> void:
	var speed := fall_speed * _weather.fall_speed
	for index: int in _particle_count():
		# Each flake sways on its own beat as it drifts down with the wind.
		var sway := sin(_phase * 1.7 + float(index)) * 3.0
		var x := fposmod(float(index * 71) + _phase * _weather.wind * 6.0 + sway, viewport_size.x + 16.0) - 8.0
		var y := fposmod(float(index * 43) + _phase * speed, viewport_size.y + 16.0) - 8.0
		draw_rect(Rect2(x, y, 2.0, 2.0), _weather.particle_color)

func _particle_count() -> int:
	return roundi(float(particles) * _weather.density)
