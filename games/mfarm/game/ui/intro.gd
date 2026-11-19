class_name MFarmIntro
extends Control

## The old game's opening, played once as a new game starts on the beach: a
## comic of the storm that took the farmer's boat, picture by picture over
## Calm 4 (`COMIC`, timed as the old timeline was), then the farmer wakes,
## looks about and meets Mike (`lines`). The player cannot act and the clock
## stands still until it is over. Esc skips it until the talk starts.

signal finished

const LOCK := &"mfarm_intro"
const MUSIC_LAYER := &"mfarm_intro"
const MUSIC := &"music_calm_4"
const ART := "res://game/unity/art/Intro/%s.tres"
const BACKGROUND := Color(0.067, 0.102, 0.18)
## The old canvas was 320 by 180 with y up from its middle; the view is
## twice that.
const CANVAS_SCALE := 2.0
const VIEW_CENTRE := Vector2(320, 180)
## When the comic starts to fade out and when it is gone, in seconds.
const COMIC_FADE_FROM := 21.53
const COMIC_END := 23.5
## After the comic: when the farmer looks left, right and down, talks, and
## (after the talk) looks up and has the controls back.
const LOOKS: Array[Array] = [[0.12, Vector2.LEFT], [1.12, Vector2.RIGHT], [2.12, Vector2.DOWN]]
const TALK_AT := 3.12
const LOOK_UP_SECONDS := 1.0

## The comic's pictures in drawing order: the art, its size and its centre on
## the old canvas, when it fades in (from, to), and, for one that slides in,
## where it is at moments of the slide (time, centre), the last at rest. The
## lightning of the fourth picture never showed in the old game and is left
## out.
const COMIC: Array[Dictionary] = [
	{"art": "Background/bg_01", "size": Vector2(78, 61), "at": Vector2(-112.8, 45.3), "fade": Vector2(0.0, 2.45)},
	{"art": "Sea/sea_01", "size": Vector2(66, 18), "at": Vector2(-118.8, 23.8), "fade": Vector2(0.0, 2.45)},
	{"art": "Background/bg_02", "size": Vector2(78, 61), "at": Vector2(-42.8, 45.3), "fade": Vector2(3.42, 5.03)},
	{"art": "Sea/lighting_01", "size": Vector2(36, 54), "at": Vector2(-52.8, 42.2), "fade": Vector2(3.42, 5.03)},
	{"art": "Background/bg_03", "size": Vector2(85, 81), "at": Vector2(-109.3, -37.1), "fade": Vector2(5.03, 9.22)},
	{"art": "Sea/sea_02", "size": Vector2(85, 81), "at": Vector2(-109.6, -40.2), "fade": Vector2(5.03, 9.22)},
	{"art": "Background/bg_04", "size": Vector2(60, 81), "at": Vector2(-31.5, -37.3), "fade": Vector2(9.22, 10.88)},
	{"art": "Background/bg_05", "size": Vector2(76, 89), "at": Vector2(42, 31.2), "fade": Vector2(10.88, 13.45)},
	{"art": "Sea/sea_03", "size": Vector2(76, 60), "at": Vector2(42, 16.7), "fade": Vector2(10.88, 13.45)},
	{"art": "Background/bg_07", "size": Vector2(73, 50), "at": Vector2(41.7, -47.2), "fade": Vector2(13.45, 15.75)},
	{"art": "Sea/sea_04", "size": Vector2(73, 43), "at": Vector2(41.7, -50.9), "fade": Vector2(13.45, 15.75)},
	{"art": "Background/bg_06", "size": Vector2(70, 52), "at": Vector2(120.2, 49.8), "fade": Vector2(15.75, 18.07)},
	{"art": "Background/bg_08", "size": Vector2(69, 94), "at": Vector2(120.1, -31.2), "fade": Vector2(18.07, 19.9)},
	{"art": "Character/character_01", "size": Vector2(83, 76), "at": Vector2(-113.7, 44.1), "fade": Vector2(1.33, 3.42),
		"slide": [[1.33, Vector2(-193.5, 44.1)], [3.42, Vector2(-124.9, 44.1)], [COMIC_FADE_FROM, Vector2(-113.7, 44.1)]]},
	{"art": "Character/character_02", "size": Vector2(58, 55), "at": Vector2(-27.4, 38.3), "fade": Vector2(3.43, 5.03)},
	{"art": "Character/character_03", "size": Vector2(34, 61), "at": Vector2(-83.7, -51), "fade": Vector2(7.03, 9.22),
		"slide": [[7.03, Vector2(-49.2, -51)], [9.18, Vector2(-83.9, -51)], [COMIC_FADE_FROM, Vector2(-83.7, -51)]]},
	{"art": "Character/character_04", "size": Vector2(93, 93), "at": Vector2(-18.5, -32), "fade": Vector2(9.22, 10.88)},
	{"art": "Character/character_05", "size": Vector2(50, 67), "at": Vector2(54.4, 20.5), "fade": Vector2(10.88, 13.45)},
	{"art": "Character/character_06", "size": Vector2(23, 49), "at": Vector2(66.6, -46.7), "fade": Vector2(13.45, 15.75)},
	{"art": "Character/character_06-1", "size": Vector2(46, 18), "at": Vector2(35.2, -58.1), "fade": Vector2(13.45, 15.75)},
	{"art": "Character/character_07", "size": Vector2(45, 51), "at": Vector2(120.2, 49.2), "fade": Vector2(15.75, 18.07),
		"slide": [[15.75, Vector2(182.8, 49.2)], [18.07, Vector2(121.2, 49.2)], [COMIC_FADE_FROM, Vector2(120.2, 49.2)]]},
	{"art": "Character/character_08", "size": Vector2(69, 86), "at": Vector2(119.6, -35.2), "fade": Vector2(18.07, 19.9)},
	{"art": "Sign/sign_01", "size": Vector2(48, 72), "at": Vector2(-51.1, 4.5), "fade": Vector2(9.22, 10.88)},
	{"art": "Sign/sign_02", "size": Vector2(83, 75), "at": Vector2(37.7, 46), "fade": Vector2(10.88, 13.45),
		"slide": [[10.88, Vector2(37.7, 127.1)], [13.45, Vector2(37.7, 42.5)], [COMIC_FADE_FROM, Vector2(37.7, 46)]]},
	{"art": "Sign/sign_03", "size": Vector2(32, 42), "at": Vector2(100.4, 60.8), "fade": Vector2(15.75, 18.07),
		"slide": [[15.75, Vector2(100.4, 110.8)], [18.07, Vector2(100.4, 56.3)], [COMIC_FADE_FROM, Vector2(100.4, 60.8)]]},
]

## What the farmer and Mike say once the farmer wakes.
@export var lines: Array[MFarmDialogueLine] = []

var _comic: Control
var _comic_tween: Tween
var _playing := false
var _talking := false

func _ready() -> void:
	add_to_group(&"mfarm_intro")
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false
	GameSession.new_game_started.connect(_on_new_game_started)
	# The comic covers the beach from the first frame of a new game, before
	# the view fades in.
	if GameSession.is_starting_new_game():
		_begin()

func _exit_tree() -> void:
	if _playing:
		_release()

## Whether the intro plays: the player cannot act until it ends.
func is_playing() -> bool:
	return _playing

## Plays the intro from the start; `finished` follows its end.
func play() -> void:
	_begin()
	_comic_tween = _animate_comic()
	_comic_tween.finished.connect(_end_comic)

## Ends the intro at once, the comic, the looks and the talk.
func skip() -> void:
	if not _playing:
		return
	var talking := _talking
	_end()
	if talking:
		var box := get_tree().get_first_node_in_group(&"mfarm_dialogue_box") as MFarmDialogueBox
		if box != null:
			box.stop()

func _on_new_game_started() -> void:
	if _comic_tween == null:
		play()

func _begin() -> void:
	if _playing:
		return
	_playing = true
	InputLock.lock(LOCK, false, self)
	WorldClock.paused = true
	GameAudio.push_music(MUSIC_LAYER, MUSIC)
	visible = true
	_comic = _build_comic()
	add_child(_comic)

func _build_comic() -> Control:
	var comic := ColorRect.new()
	comic.name = "Comic"
	comic.color = BACKGROUND
	comic.mouse_filter = Control.MOUSE_FILTER_STOP
	comic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for picture: Dictionary in COMIC:
		var rect := TextureRect.new()
		rect.texture = load(ART % picture["art"]) as Texture2D
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_SCALE
		rect.size = (picture["size"] as Vector2) * CANVAS_SCALE
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rect.modulate.a = 0.0
		var slide: Array = picture.get("slide", [])
		rect.position = _view_corner(slide[0][1] if not slide.is_empty() else picture["at"], rect.size)
		comic.add_child(rect)
	var hint := MFarmUiArt.label("Esc to skip", 8, MFarmUiArt.LIGHT_TEXT_COLOR)
	hint.name = "SkipHint"
	hint.modulate.a = 0.6
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.size = Vector2(160, 12)
	MFarmUiArt.place(comic, hint, Vector2(472, 342))
	return comic

func _animate_comic() -> Tween:
	var tween := create_tween().set_parallel()
	for index: int in COMIC.size():
		var picture := COMIC[index]
		var rect := _comic.get_child(index) as TextureRect
		var fade: Vector2 = picture["fade"]
		tween.tween_property(rect, ^"modulate:a", 1.0, fade.y - fade.x).set_delay(fade.x)
		var slide: Array = picture.get("slide", [])
		for key: int in range(1, slide.size()):
			var from: float = slide[key - 1][0]
			var step := tween.tween_property(rect, ^"position", _view_corner(slide[key][1], rect.size), slide[key][0] - from).set_delay(from)
			# The slide in eases out; the drift after it barely moves.
			step.set_trans(Tween.TRANS_CUBIC if key == 1 else Tween.TRANS_SINE).set_ease(Tween.EASE_OUT if key == 1 else Tween.EASE_IN_OUT)
	tween.tween_property(_comic, ^"modulate:a", 0.0, COMIC_END - COMIC_FADE_FROM).set_delay(COMIC_FADE_FROM)
	return tween

# The top left in the view of a picture of `size` (in the view) centred at
# `centre` on the old canvas.
static func _view_corner(centre: Vector2, size: Vector2) -> Vector2:
	return VIEW_CENTRE + Vector2(centre.x, -centre.y) * CANVAS_SCALE - size * 0.5

func _end_comic() -> void:
	if not _playing:
		return
	_free_comic()
	GameAudio.pop_music(MUSIC_LAYER)
	var player := get_tree().get_first_node_in_group(&"player") as TopDownPlayer
	var waited := 0.0
	for look: Array in LOOKS:
		if not await _wait(look[0] - waited):
			return
		waited = look[0]
		if player != null and is_instance_valid(player):
			player.face(look[1])
	if not await _wait(TALK_AT - waited):
		return
	var box := get_tree().get_first_node_in_group(&"mfarm_dialogue_box") as MFarmDialogueBox
	if box != null and not lines.is_empty():
		_talking = true
		box.play(lines)
		await box.finished
		_talking = false
		if not _playing:
			return
	if player != null and is_instance_valid(player):
		player.face(Vector2.UP)
	if await _wait(LOOK_UP_SECONDS):
		_end()

# Waits `seconds` while the world runs: false when the intro ended meanwhile.
func _wait(seconds: float) -> bool:
	if seconds > 0.0:
		await get_tree().create_timer(seconds, false).timeout
	return _playing and is_inside_tree()

func _end() -> void:
	if not _playing:
		return
	_free_comic()
	_release()
	visible = false
	finished.emit()

func _free_comic() -> void:
	if _comic_tween != null and _comic_tween.is_valid():
		_comic_tween.kill()
	if _comic != null:
		_comic.queue_free()
		_comic = null

func _release() -> void:
	_playing = false
	_talking = false
	InputLock.unlock(LOCK)
	WorldClock.paused = false
	GameAudio.pop_music(MUSIC_LAYER)

func _unhandled_input(event: InputEvent) -> void:
	if not _playing or _talking:
		return
	if event.is_action_pressed(&"ui_cancel") or event.is_action_pressed(&"pause"):
		get_viewport().set_input_as_handled()
		skip()
