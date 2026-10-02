class_name DayNightModulate
extends CanvasModulate

@export var night_color := Color(0.34, 0.42, 0.62, 1.0)
@export var dawn_color := Color(0.82, 0.69, 0.58, 1.0)
@export var day_color := Color.WHITE
@export var dusk_color := Color(0.83, 0.58, 0.48, 1.0)

func _ready() -> void:
	WorldClock.minute_changed.connect(_on_minute_changed)
	_apply(WorldClock.minute_of_day)

func _on_minute_changed(_day: int, minute_of_day: int) -> void:
	_apply(minute_of_day)

func _apply(minute_of_day: int) -> void:
	color = color_for_minute(minute_of_day)

func color_for_minute(minute_of_day: int) -> Color:
	var minute := posmod(minute_of_day, GameClock.MINUTES_PER_DAY)
	if minute < 5 * 60:
		return night_color
	if minute < 7 * 60:
		return night_color.lerp(dawn_color, inverse_lerp(5.0 * 60.0, 7.0 * 60.0, float(minute)))
	if minute < 9 * 60:
		return dawn_color.lerp(day_color, inverse_lerp(7.0 * 60.0, 9.0 * 60.0, float(minute)))
	if minute < 17 * 60:
		return day_color
	if minute < 19 * 60:
		return day_color.lerp(dusk_color, inverse_lerp(17.0 * 60.0, 19.0 * 60.0, float(minute)))
	if minute < 21 * 60:
		return dusk_color.lerp(night_color, inverse_lerp(19.0 * 60.0, 21.0 * 60.0, float(minute)))
	return night_color
