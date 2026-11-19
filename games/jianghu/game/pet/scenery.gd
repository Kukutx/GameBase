class_name JianghuScenery
extends Control

## An ink-wash landscape behind the hero when the game runs in a window: a
## paper sky, a red sun, ranges of mountains fading into mist, and a ledge
## with a pine where the hero sits. Its colours follow the region the hero
## roams (`set_region()`), and the shapes are the same every time.

const PAPER := Color(0.96, 0.93, 0.86)
const SUN := Color(0.8, 0.27, 0.22, 0.85)
const LEDGE := Color(0.24, 0.22, 0.21)
const PINE := Color(0.16, 0.24, 0.2)

## How high the ledge the hero stands on is, from the bottom.
var ledge_height := 56.0
var sky := Color(0.95, 0.91, 0.82)
var hills := Color(0.45, 0.52, 0.47)
var t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func set_region(region: JianghuRegionData) -> void:
	if region == null:
		return
	sky = region.sky
	hills = region.hills
	queue_redraw()

func _draw() -> void:
	# The paper sky, warmer towards the horizon.
	var steps := 12
	for i: int in steps:
		var band := Rect2(0, size.y * i / steps, size.x, size.y / steps + 1.0)
		draw_rect(band, PAPER.lerp(sky, float(i) / steps))
	draw_circle(Vector2(size.x * 0.74, size.y * 0.2), minf(size.x, size.y) * 0.075, SUN, true, -1.0, true)
	# Far ranges first, paler; each one darker and nearer.
	for layer: int in 4:
		var depth := float(layer) / 3.0
		var color := hills.lerp(PAPER, 0.75 - depth * 0.6)
		color.a = 0.55 + depth * 0.35
		_range(size.y * (0.42 + depth * 0.13), size.y * (0.16 - depth * 0.03), 17 + layer * 31, color)
		_mist(size.y * (0.47 + depth * 0.13), layer)
	_ledge()

func _range(base: float, height: float, seed_value: int, color: Color) -> void:
	var points := PackedVector2Array([Vector2(0, size.y)])
	var segments := 28
	for i: int in segments + 1:
		var x := size.x * i / segments
		var u := float(i) / segments
		var y := base - height * (0.55 + 0.45 * sin(u * 5.3 + seed_value) * sin(u * 2.1 + seed_value * 0.7))
		y -= height * 0.25 * absf(sin(u * 13.0 + seed_value * 1.3))
		points.append(Vector2(x, y))
	points.append(Vector2(size.x, size.y))
	draw_colored_polygon(points, color)

func _mist(y: float, layer: int) -> void:
	var drift := fmod(t * (4.0 + layer * 2.0), size.x + 160.0) - 80.0
	for i: int in 3:
		var x := fmod(drift + i * size.x / 2.5 + layer * 47.0, size.x + 160.0) - 80.0
		var rect := Rect2(x - 70, y - 6, 140, 12)
		draw_rect(rect, Color(1, 1, 1, 0.22))

func _ledge() -> void:
	var top := size.y - ledge_height
	var rock := PackedVector2Array([
		Vector2(0, size.y), Vector2(0, top + 10), Vector2(size.x * 0.2, top + 2),
		Vector2(size.x * 0.5, top), Vector2(size.x * 0.82, top + 4), Vector2(size.x, top + 14),
		Vector2(size.x, size.y)])
	draw_colored_polygon(rock, LEDGE)
	draw_polyline(PackedVector2Array([rock[1], rock[2], rock[3], rock[4], rock[5]]), Color(0.05, 0.05, 0.05, 0.6), 2.0, true)
	# A pine leaning over the edge.
	var root := Vector2(size.x * 0.12, top + 4)
	var crown := root + Vector2(26, -96)
	draw_line(root, root.lerp(crown, 0.5) + Vector2(-8, 0), Color(0.2, 0.15, 0.12), 6.0, true)
	draw_line(root.lerp(crown, 0.5) + Vector2(-8, 0), crown, Color(0.2, 0.15, 0.12), 4.0, true)
	for i: int in 4:
		var at := root.lerp(crown, 0.45 + i * 0.18)
		var sway := sin(t * 0.8 + i) * 1.5
		var width := 46.0 - i * 9.0
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(-width * 0.55, 6 + sway), at + Vector2(width * 0.5, 2 + sway),
			at + Vector2(width * 0.15, -10), at + Vector2(-width * 0.25, -9)]), PINE)
