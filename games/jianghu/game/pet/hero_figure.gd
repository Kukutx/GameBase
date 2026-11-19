class_name JianghuHeroFigure
extends Node2D

## The little hero, drawn from shapes so it stays sharp at any size: a round
## head with a topknot and a red ribbon, a blue-green robe with a red sash and
## a sword on the back. The origin is between the feet. `pose` picks what the
## body does; the time (`t`) moves the ribbon, the breath and the sword.

enum Pose { IDLE, MEDITATE, PRACTICE, WALK, SLEEP, HELD, CHEER }

const SKIN := Color(0.97, 0.86, 0.77)
const HAIR := Color(0.16, 0.13, 0.12)
const ROBE := Color(0.25, 0.5, 0.55)
const ROBE_DARK := Color(0.18, 0.37, 0.41)
const TROUSERS := Color(0.22, 0.22, 0.28)
const SASH := Color(0.72, 0.19, 0.17)
const STEEL := Color(0.86, 0.9, 0.93)
const HILT := Color(0.42, 0.27, 0.16)
const INK := Color(0.12, 0.1, 0.1)
const BLUSH := Color(0.95, 0.5, 0.5, 0.45)

var pose := Pose.IDLE:
	set(value):
		pose = value
		queue_redraw()
## 1 faces right, -1 faces left.
var facing := 1.0
## The colour of the glow while the hero cultivates.
var aura := Color(0.95, 0.85, 0.5)
var t := 0.0
## Seconds until the next blink, and how long the eyes stay shut.
var _blink_in := 2.5
var _blink := 0.0

func _process(delta: float) -> void:
	t += delta
	_blink_in -= delta
	if _blink_in <= 0.0:
		_blink = 0.14
		_blink_in = randf_range(2.0, 5.0)
	_blink = maxf(_blink - delta, 0.0)
	queue_redraw()

func _draw() -> void:
	match pose:
		Pose.MEDITATE, Pose.SLEEP:
			_draw_seated()
		_:
			_draw_standing()

func _draw_standing() -> void:
	var lift := 0.0
	var step := 0.0
	match pose:
		Pose.WALK:
			lift = absf(sin(t * 9.0)) * 2.5
			step = sin(t * 9.0) * 4.0
		Pose.CHEER:
			lift = absf(sin(t * 7.0)) * 12.0
		Pose.HELD:
			lift = 0.0
		Pose.PRACTICE:
			step = 3.0
		_:
			lift = sin(t * 2.0) * 0.8
	_shadow(1.0 - lift / 30.0)
	draw_set_transform(Vector2(0.0, -lift), 0.0, Vector2(facing, 1.0))
	# Legs, dangling while held.
	if pose == Pose.HELD:
		var swing := sin(t * 10.0) * 0.35
		_leg(Vector2(-5, -12), swing)
		_leg(Vector2(5, -12), -swing)
	else:
		_leg(Vector2(-5 - step * 0.5, -12), 0.0)
		_leg(Vector2(5 + step * 0.5, -12), 0.0)
	if pose != Pose.PRACTICE:
		_sword_on_back()
	_robe(Vector2(0, -36), 22.0, 31.0, 26.0)
	_arms()
	_head(Vector2(0, -52), 0.0)
	if pose == Pose.PRACTICE:
		_practice_arm()
	draw_set_transform(Vector2.ZERO)

func _draw_seated() -> void:
	var breath := sin(t * 1.6) * 1.2
	_aura_glow()
	_shadow(1.3)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1.0))
	# Crossed legs: a wide lap.
	_ellipse(Vector2(0, -6), Vector2(19, 6.5), TROUSERS)
	_ellipse(Vector2(-12, -3), Vector2(6, 3), INK)
	_ellipse(Vector2(12, -3), Vector2(6, 3), INK)
	_sword_on_back(Vector2(0, 10))
	_robe(Vector2(0, -27 - breath * 0.3), 22.0, 30.0, 19.0)
	# Hands meet in front of the sash.
	draw_line(Vector2(-11, -24), Vector2(-3, -14), ROBE_DARK, 6.0, true)
	draw_line(Vector2(11, -24), Vector2(3, -14), ROBE_DARK, 6.0, true)
	draw_circle(Vector2(0, -14), 3.6, SKIN, true, -1.0, true)
	var tilt := 0.22 if pose == Pose.SLEEP else 0.0
	_head(Vector2(0, -43 - breath * 0.5), tilt)
	draw_set_transform(Vector2.ZERO)
	if pose == Pose.MEDITATE:
		_qi_motes()
	else:
		_sleep_marks()

func _shadow(size: float) -> void:
	_ellipse(Vector2(0, 0), Vector2(20, 4.5) * size, Color(0, 0, 0, 0.18))

func _leg(hip: Vector2, angle: float) -> void:
	var foot := hip + Vector2(0, 11).rotated(angle)
	draw_line(hip, foot, TROUSERS, 6.0, true)
	_ellipse(foot + Vector2(1, 0.5), Vector2(4, 2.2), INK)

func _robe(neck: Vector2, top: float, bottom: float, height: float) -> void:
	var hem := neck.y + height
	var robe := PackedVector2Array([
		neck + Vector2(-top / 2.0, 0), neck + Vector2(top / 2.0, 0),
		Vector2(bottom / 2.0, hem), Vector2(bottom / 4.0, hem + 2.0),
		Vector2(-bottom / 4.0, hem + 2.0), Vector2(-bottom / 2.0, hem)])
	draw_colored_polygon(robe, ROBE)
	draw_polyline(robe + PackedVector2Array([robe[0]]), ROBE_DARK, 1.2, true)
	# A white collar crossing left over right.
	draw_line(neck + Vector2(-5, 0), neck + Vector2(3, 9), Color.WHITE, 2.0, true)
	draw_line(neck + Vector2(5, 0), neck + Vector2(0, 5), Color.WHITE, 2.0, true)
	# The sash and its knot.
	var sash := neck.y + height * 0.45
	draw_rect(Rect2(-top / 2.0 - 1.5, sash, top + 3.0, 4.0), SASH)
	var flutter := sin(t * 3.0) * 1.5
	draw_line(Vector2(-top / 2.0 + 2, sash + 3), Vector2(-top / 2.0 - 3, sash + 10 + flutter), SASH, 2.0, true)

func _arms() -> void:
	var left_hand := Vector2(-14, -21)
	var right_hand := Vector2(14, -21)
	match pose:
		Pose.CHEER, Pose.HELD:
			var wave := sin(t * 12.0) * 2.0
			left_hand = Vector2(-16, -50 + wave)
			right_hand = Vector2(16, -50 - wave)
		Pose.WALK:
			left_hand.x -= sin(t * 9.0) * 3.0
			right_hand.x -= sin(t * 9.0) * 3.0
		Pose.PRACTICE:
			left_hand = Vector2(-12, -24)
			draw_line(Vector2(-10, -34), left_hand, ROBE_DARK, 6.0, true)
			draw_circle(left_hand, 3.0, SKIN, true, -1.0, true)
			return
	draw_line(Vector2(-10, -34), left_hand, ROBE_DARK, 6.0, true)
	draw_line(Vector2(10, -34), right_hand, ROBE_DARK, 6.0, true)
	draw_circle(left_hand, 3.0, SKIN, true, -1.0, true)
	draw_circle(right_hand, 3.0, SKIN, true, -1.0, true)

# The sword arm: a sweeping cut, with the trail of the blade.
func _practice_arm() -> void:
	var phase := fmod(t * 1.4, 1.0)
	var angle := lerpf(-1.5, 0.8, ease(phase / 0.45, 0.4)) if phase < 0.45 else lerpf(0.8, -1.5, (phase - 0.45) / 0.55)
	var shoulder := Vector2(10, -34)
	var hand := shoulder + Vector2(13, 0).rotated(angle)
	if phase < 0.45 and phase > 0.08:
		var trail := PackedVector2Array()
		var from := lerpf(-1.5, 0.8, ease(maxf(phase - 0.12, 0.0) / 0.45, 0.4))
		for i: int in 9:
			trail.append(shoulder + Vector2(44, 0).rotated(lerpf(from, angle, i / 8.0)))
		draw_polyline(trail, Color(1, 1, 1, 0.55), 3.0, true)
	draw_line(shoulder, hand, ROBE_DARK, 6.0, true)
	var tip := hand + Vector2(32, 0).rotated(angle)
	draw_line(hand, tip, STEEL, 2.5, true)
	draw_line(hand - Vector2(0, 4).rotated(angle), hand + Vector2(0, 4).rotated(angle), HILT, 2.5, true)
	draw_circle(hand, 3.0, SKIN, true, -1.0, true)

func _sword_on_back(offset := Vector2.ZERO) -> void:
	var hilt := Vector2(-12, -64) + offset
	var tip := Vector2(14, -22) + offset
	draw_line(hilt + (tip - hilt) * 0.18, tip, Color(0.3, 0.24, 0.2), 4.0, true)
	draw_line(hilt, hilt + (tip - hilt) * 0.18, HILT, 3.0, true)
	var tassel := hilt + Vector2(sin(t * 2.5) * 2.0 - 3.0, 7.0)
	draw_line(hilt, tassel, SASH, 1.5, true)

func _head(center: Vector2, tilt: float) -> void:
	draw_set_transform(center, tilt, Vector2(facing, 1.0))
	# Ribbon tails from the topknot, in the wind.
	var wind := sin(t * 2.2)
	for i: int in 2:
		var tail := PackedVector2Array()
		for k: int in 6:
			var along := k / 5.0
			tail.append(Vector2(-4.0 - along * 16.0, -18.0 + along * 6.0 + sin(t * 4.0 + along * 3.0 + i) * along * 3.0 + i * 3.0 + wind * along))
		draw_polyline(tail, SASH, 2.2 - i * 0.6, true)
	draw_circle(Vector2(0, -19), 6.5, HAIR, true, -1.0, true)
	draw_circle(Vector2.ZERO, 17.0, SKIN, true, -1.0, true)
	# Hair: the crown and the fringe.
	var hair := PackedVector2Array()
	for k: int in 13:
		hair.append(Vector2(0, 0).lerp(Vector2(-17.5, 0).rotated(PI * k / 12.0), 1.0))
	hair.append(Vector2(15, -3))
	hair.append(Vector2(9, -7))
	hair.append(Vector2(4, -2))
	hair.append(Vector2(-2, -7))
	hair.append(Vector2(-9, -3))
	hair.append(Vector2(-16, 2))
	draw_colored_polygon(hair, HAIR)
	draw_rect(Rect2(-3, -23, 6, 3), SASH)
	_face()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(facing, 1.0))

func _face() -> void:
	var shut := _blink > 0.0 or pose in [Pose.MEDITATE, Pose.SLEEP]
	for side: float in [-1.0, 1.0]:
		var eye := Vector2(6.5 * side, 3.0)
		if pose == Pose.CHEER:
			draw_arc(eye + Vector2(0, 1.5), 2.6, PI * 1.1, PI * 1.9, 6, INK, 1.6, true)
		elif pose == Pose.HELD:
			draw_line(eye + Vector2(-2.5 * side, -2), eye + Vector2(2 * side, 0), INK, 1.6, true)
			draw_line(eye + Vector2(2 * side, 0), eye + Vector2(-2.5 * side, 2), INK, 1.6, true)
		elif shut:
			draw_arc(eye, 2.6, PI * 0.1, PI * 0.9, 6, INK, 1.6, true)
		else:
			_ellipse(eye, Vector2(2.2, 3.0), INK)
			draw_circle(eye + Vector2(0.8, -1.2), 0.9, Color.WHITE, true, -1.0, true)
		draw_circle(Vector2(10.5 * side, 8.0), 2.6, BLUSH, true, -1.0, true)
	if pose == Pose.HELD:
		draw_circle(Vector2(0, 10), 2.0, INK, true, -1.0, true)
	elif pose == Pose.CHEER:
		draw_arc(Vector2(0, 8.5), 3.0, 0.1, PI - 0.1, 8, INK, 1.5, true)
	else:
		draw_arc(Vector2(0, 9), 2.0, 0.3, PI - 0.3, 6, INK, 1.2, true)

func _aura_glow() -> void:
	var pulse := 0.5 + 0.5 * sin(t * 1.6)
	for ring: int in 3:
		var color := aura
		color.a = 0.10 - ring * 0.025 + pulse * 0.04
		_ellipse(Vector2(0, -26), Vector2(30 + ring * 7, 34 + ring * 8) * (0.95 + pulse * 0.05), color)

func _qi_motes() -> void:
	for i: int in 10:
		var phase := fmod(t * 0.35 + i / 10.0, 1.0)
		var x := sin(i * 2.39996) * 24.0 + sin(t + i) * 3.0
		var color := aura
		color.a = (1.0 - phase) * 0.9
		draw_circle(Vector2(x, -8.0 - phase * 70.0), 1.6 + (1.0 - phase), color, true, -1.0, true)

func _sleep_marks() -> void:
	var font := ThemeDB.fallback_font
	for i: int in 3:
		var phase := fmod(t * 0.4 + i / 3.0, 1.0)
		var color := Color(0.35, 0.4, 0.55, 1.0 - phase)
		draw_string(font, Vector2(14 + phase * 16.0, -60 - phase * 26.0), "z", HORIZONTAL_ALIGNMENT_LEFT, -1, int(9 + phase * 8.0), color)

func _ellipse(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for k: int in 24:
		points.append(center + Vector2(cos(TAU * k / 24.0) * radius.x, sin(TAU * k / 24.0) * radius.y))
	draw_colored_polygon(points, color)
