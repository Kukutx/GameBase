extends Node2D

## A light of the old project that follows the time of day: the location's
## sky (`Outside Global Light`, a `CanvasModulate`) or a lamp (`WallLight`,
## a `PointLight2D` lit at night). Day turns to night at `NIGHT_STARTS`, night
## to day at `MORNING_STARTS`, over `CHANGE_SECONDS`; a location entered, or
## a clock run on many minutes at once (the G key), shows the light
## of the hour at once.

const MORNING_STARTS := 5 * 60
const NIGHT_STARTS := 19 * 60
const CHANGE_SECONDS := 25.0
const SKY_DAY := Color.WHITE
## The old project's night sky (`Outside Global Light`): colour
## (0.216, 0.275, 0.647) at intensity 0.7. Every season shares it; the old
## data had spring only, and lights stopped changing after spring.
const SKY_NIGHT := Color(0.151, 0.192, 0.453)
const LAMP_COLOR := Color(1.0, 0.843, 0.471)
const LAMP_NIGHT_ENERGY := 1.5

@export var pattern_id: StringName

var _sky: CanvasModulate
var _lamp: PointLight2D
var _night := false
var _tween: Tween
# How far the light is from day (0) to night (1), and the frame of the last
# minute it followed.
var _amount := 0.0
var _minute_frame := -1

func _ready() -> void:
	if pattern_id == &"Outside Global Light":
		_sky = CanvasModulate.new()
		add_child(_sky)
	else:
		_lamp = PointLight2D.new()
		_lamp.color = LAMP_COLOR
		_lamp.texture = _make_glow()
		_lamp.texture_scale = 1.5
		add_child(_lamp)
	_night = is_night(WorldClock.minute_of_day)
	_apply(1.0 if _night else 0.0)
	WorldClock.minute_changed.connect(_on_minute_changed)

static func is_night(minute_of_day: int) -> bool:
	return minute_of_day >= NIGHT_STARTS or minute_of_day < MORNING_STARTS

func _on_minute_changed(_day: int, minute_of_day: int) -> void:
	var night := is_night(minute_of_day)
	# A second minute in one frame: the clock runs on faster than any light
	# could change, so the light keeps up at once.
	var skipping := Engine.get_process_frames() == _minute_frame
	_minute_frame = Engine.get_process_frames()
	if night == _night:
		return
	_night = night
	if _tween != null:
		_tween.kill()
	var target := 1.0 if night else 0.0
	if skipping:
		_apply(target)
		return
	_tween = create_tween()
	_tween.tween_method(_apply, _amount, target, CHANGE_SECONDS * absf(target - _amount))

# `amount` 0 is day, 1 night.
func _apply(amount: float) -> void:
	_amount = amount
	if _sky != null:
		_sky.color = SKY_DAY.lerp(SKY_NIGHT, amount)
	if _lamp != null:
		_lamp.energy = LAMP_NIGHT_ENERGY * amount
		_lamp.enabled = amount > 0.0

static func _make_glow() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.set_color(1, Color(1, 1, 1, 0))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(0.5, 0.0)
	texture.width = 96
	texture.height = 96
	return texture
