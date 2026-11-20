class_name SheetAnimator
extends RefCounted

## Plays the frames of a sprite sheet, cells of `frame_size` laid out in rows,
## through a `Sprite2D`'s region: a run of frames (`play()`), at `fps`, that
## loops or stays on its last frame (a death). The sprite's texture is the
## sheet, with its region on.

var sprite: Sprite2D
var frame_size := Vector2i(32, 32)
var fps := 12

var _frames := Vector2i.ZERO
var _loops := true
var _frame := 0
var _time := 0.0
var _playing := false

func _init(target: Sprite2D, cell_size: Vector2i, frames_per_second: int) -> void:
	sprite = target
	frame_size = Vector2i(maxi(cell_size.x, 1), maxi(cell_size.y, 1))
	fps = maxi(frames_per_second, 1)

## Plays frames `frames.x` to `frames.y`, looping or, unless `loops`, staying
## on the last. The same run already playing goes on where it is, unless
## `restart`.
func play(frames: Vector2i, loops := true, restart := false) -> void:
	if _playing and not restart and frames == _frames and loops == _loops and _frame >= frames.x and _frame <= frames.y:
		return
	_frames = frames
	_loops = loops
	_playing = true
	_time = 0.0
	_frame = frames.x
	_show()

## Moves the run on by `delta` seconds.
func advance(delta: float) -> void:
	if not _playing:
		return
	_time += delta * fps
	while _time >= 1.0:
		_time -= 1.0
		_frame += 1
		if _frame > _frames.y:
			_frame = _frames.x if _loops else _frames.y
		_show()

## The frame shown, counted from the sheet's first cell.
func get_frame() -> int:
	return _frame

func _show() -> void:
	if sprite == null or sprite.texture == null:
		return
	var columns := maxi(sprite.texture.get_width() / frame_size.x, 1)
	var cell := Vector2i(_frame % columns, _frame / columns)
	sprite.region_rect = Rect2(Vector2(cell * frame_size), Vector2(frame_size))
