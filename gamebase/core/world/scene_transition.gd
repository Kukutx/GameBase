class_name GameSceneTransition
extends CanvasLayer

## Changes the scene behind a fade: the screen covers while the scene loads
## (on a thread where the platform has them; a web build without threads
## loads it when the change is asked for), the scene changes, and the screen
## clears again.
## `WorldTravel` changes locations through it.
##
## A change asked for while the screen clears after the last one starts at
## once from where the fade is; only one change covers the screen at a time.

## Emitted when the scene of an accepted change could not open; the screen
## clears again.
signal scene_change_failed(path: String)

const FADE_SECONDS := 0.12

## Seconds each fade takes; none with reduced motion.
var fade_seconds := FADE_SECONDS

var _overlay: ColorRect
var _covering := false
var _fade: Tween

func _ready() -> void:
	layer = 1000
	_overlay = ColorRect.new()
	_overlay.name = "FadeOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.02, 0.03, 0.035, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	add_child(_overlay)

## Covers the screen, opens the scene at `path` and clears the screen. False
## when there is no scene at `path` or another change covers the screen; true
## when the change starts (`scene_change_failed` follows if it then cannot
## open).
func change_scene(path: String) -> bool:
	if _covering or path.is_empty():
		return false
	# No type hint: what the load gives is checked once it is done, and a
	# resource that is no scene then fails the change instead of the loader.
	if not ResourceLoader.exists(path) or ResourceLoader.load_threaded_request(path) != OK:
		push_error("Transition: scene is unavailable: %s" % path)
		return false
	_covering = true
	_run(path)
	return true

## Whether a change covers the screen: from its request until its scene opens.
func is_covering() -> bool:
	return _covering

func _run(path: String) -> void:
	_stop_fade()
	var seconds := 0.0 if GameSettings.reduced_motion else fade_seconds
	if seconds > 0.0:
		_overlay.visible = true
		_fade = create_tween()
		_fade.tween_property(_overlay, "color:a", 1.0, seconds * (1.0 - _overlay.color.a))
		await _fade.finished
	var packed: PackedScene = await _finish_loading(path)
	var error := get_tree().change_scene_to_packed(packed) if packed != null else ERR_CANT_OPEN
	_covering = false
	if error != OK:
		# Handled: the screen clears and `scene_change_failed` tells travel.
		push_warning("Transition: scene change failed (%d): %s" % [error, path])
		_clear()
		scene_change_failed.emit(path)
		return
	if seconds <= 0.0:
		_clear()
		return
	await get_tree().process_frame
	if _covering:
		# Another change took over while the scene opened.
		return
	_fade = create_tween()
	_fade.tween_property(_overlay, "color:a", 0.0, seconds)
	# Not awaited: a change that takes over kills this fade, and a killed tween
	# never finishes.
	_fade.finished.connect(_clear)

# The scene the background load of `path` gave, once it is done; null when it
# is no scene.
func _finish_loading(path: String) -> PackedScene:
	while ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
	return ResourceLoader.load_threaded_get(path) as PackedScene

func _stop_fade() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	_fade = null

func _clear() -> void:
	_stop_fade()
	_overlay.color.a = 0.0
	_overlay.visible = false
