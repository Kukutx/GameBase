class_name DayNightModulate
extends CanvasModulate

## Tints a location by the time of day: night between the calendar's
## `night_starts_at` and `night_ends_at`, with a dusk and a dawn around them.
## Each change of light takes `ramp_minutes`: the one between twilight and
## night is centred on the calendar's minute, the one between day and
## twilight comes just before dusk's and just after dawn's.

@export var night_color := Color(0.34, 0.42, 0.62, 1.0)
@export var dawn_color := Color(0.82, 0.69, 0.58, 1.0)
@export var day_color := Color.WHITE
@export var dusk_color := Color(0.83, 0.58, 0.48, 1.0)
@export_range(0, 360, 1) var ramp_minutes := 120

func _ready() -> void:
	WorldClock.minute_changed.connect(_on_minute_changed)
	_apply(WorldClock.minute_of_day)

func _on_minute_changed(_day: int, minute_of_day: int) -> void:
	_apply(minute_of_day)

func _apply(minute_of_day: int) -> void:
	color = color_for_minute(minute_of_day)

func color_for_minute(minute_of_day: int) -> Color:
	var calendar := GameCalendar.current()
	var minute := posmod(minute_of_day, GameClock.MINUTES_PER_DAY)
	if ramp_minutes <= 0:
		return night_color if calendar.is_night(minute) else day_color
	var ramp := float(ramp_minutes)
	var half := ramp / 2.0
	var from_dawn := float(_offset(minute, calendar.night_ends_at))
	if absf(from_dawn) <= half:
		return night_color.lerp(dawn_color, (from_dawn + half) / ramp)
	if from_dawn > half and from_dawn <= half + ramp:
		return dawn_color.lerp(day_color, (from_dawn - half) / ramp)
	var from_dusk := float(_offset(minute, calendar.night_starts_at))
	if absf(from_dusk) <= half:
		return dusk_color.lerp(night_color, (from_dusk + half) / ramp)
	if from_dusk < -half and from_dusk >= -half - ramp:
		return day_color.lerp(dusk_color, (from_dusk + half + ramp) / ramp)
	return night_color if calendar.is_night(minute) else day_color

# How many minutes `minute` is after `boundary` (before it when negative),
# the shorter way round the clock.
static func _offset(minute: int, boundary: int) -> int:
	var after := posmod(minute - boundary, GameClock.MINUTES_PER_DAY)
	return after - GameClock.MINUTES_PER_DAY if after > GameClock.MINUTES_PER_DAY / 2 else after
