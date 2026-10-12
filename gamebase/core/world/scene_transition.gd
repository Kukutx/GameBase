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
##
## A cutscene covers the screen without a change and clears it when it is
## done (`await Transition.cover(self)`, `await Transition.uncover()`); a
## change under a cover (a cutscene that moves the player) leaves the screen
## covered. A cover lasts until it is uncovered, or until the node that holds
## it leaves the tree; a load and the title give it back (`reset()`).
## `wait_until_clear()` waits until the screen is clear again, the fade
## included.

## Emitted when the scene of an accepted change could not open; the screen
## clears again.
signal scene_change_failed(path: String)
## Emitted when the screen is clear again after a change or a cover.
signal cleared

const FADE_SECONDS := 0.12

## Seconds each fade takes; none with reduced motion.
var fade_seconds := FADE_SECONDS

var _overlay: ColorRect
var _covering := false
# Covered by `cover()` until `uncover()`.
var _held := false
# The node whose leaving the tree gives the cover back, if any.
var _holder: Node
var _fade: Tween

func _ready() -> void:
	layer = 1000
	# A fade runs while the world is paused (a cutscene over a paused world).
	process_mode = Node.PROCESS_MODE_ALWAYS
	_overlay = ColorRect.new()
	_overlay.name = "FadeOverlay"
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.color = Color(0.02, 0.03, 0.035, 0.0)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	add_child(_overlay)

## Covers the screen, opens the scene at `path` and clears the screen, unless
## a cover holds it. False when there is no scene at `path` or another change
## covers the screen; true when the change starts (`scene_change_failed`
## follows if it then cannot open).
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

## The scene at `path`, loaded as `change_scene()` loads one while the game
## goes on; null when there is none or it is no scene.
func load_scene(path: String) -> PackedScene:
	if not ResourceLoader.exists(path) or ResourceLoader.load_threaded_request(path) != OK:
		return null
	return await _finish_loading(path)

## Whether a change covers the screen: from its request until its scene opens.
func is_covering() -> bool:
	return _covering

## Whether a cover holds the screen (`cover()`).
func is_covered() -> bool:
	return _held

## Whether the screen is clear: no change, cover or fade shows over it.
func is_clear() -> bool:
	return not _covering and not _held and not _overlay.visible

## Waits until the screen is clear (`is_clear()`); at once when it is.
func wait_until_clear() -> void:
	# Polled rather than awaited on `cleared`: the wait then resumes outside
	# the transition's own signal, and what waited may free nodes at once.
	while not is_clear():
		await get_tree().process_frame

## Covers the screen without changing the scene, for a cutscene to work behind
## it, and returns once it is covered: true then, false when a cover holds the
## screen already or it was uncovered first. Taken while a change covers the
## screen, it keeps the screen covered after the change. The screen stays
## covered until `uncover()`, or until `holder` (when given) leaves the tree.
func cover(holder: Node = null) -> bool:
	if _held:
		return false
	_held = true
	_hold(holder)
	_overlay.visible = true
	var seconds := _fade_seconds()
	# A change under way fades in by itself, and its fade is left running;
	# otherwise a fade that clears the screen stops where it is.
	if not _covering:
		_stop_fade()
	if seconds <= 0.0:
		_overlay.color.a = 1.0
	elif not _covering and _overlay.color.a < 1.0:
		_fade = create_tween()
		_fade.tween_property(_overlay, "color:a", 1.0, seconds * (1.0 - _overlay.color.a))
	# Polled rather than awaited: an `uncover()` meanwhile kills the fade, and a
	# killed tween never finishes.
	while _held and _overlay.color.a < 1.0:
		await get_tree().process_frame
	return _held

## Gives back the cover and returns once the screen is clear (after the change
## under way, if any); at once when it is.
func uncover() -> void:
	_release()
	await wait_until_clear()

## Gives back the cover at once and clears the screen unless a change is under
## way: for a load or the title, which leave nothing behind to uncover it.
func reset() -> void:
	if not _held:
		return
	_held = false
	_hold(null)
	_clear()

func _fade_seconds() -> float:
	return 0.0 if GameSettings.reduced_motion else fade_seconds

func _release() -> void:
	if not _held:
		return
	_held = false
	_hold(null)
	# A cover still fading in stops where it is; a change clears the screen
	# itself once it is done.
	_settle()

func _hold(holder: Node) -> void:
	if is_instance_valid(_holder) and _holder.tree_exiting.is_connected(_release):
		_holder.tree_exiting.disconnect(_release)
	_holder = holder
	if holder != null:
		holder.tree_exiting.connect(_release, CONNECT_ONE_SHOT)

func _run(path: String) -> void:
	var seconds := _fade_seconds()
	if seconds > 0.0 and _overlay.color.a < 1.0:
		_stop_fade()
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
		_settle()
		scene_change_failed.emit(path)
		return
	# What the new scene does as it opens and on its first frame (a cover for
	# its intro) is in place before the screen clears.
	await get_tree().scene_changed
	await get_tree().process_frame
	_settle()

# Clears the screen, fading unless reduced motion asks for none, when neither a
# change nor a cover holds it.
func _settle() -> void:
	if _covering or _held:
		return
	var seconds := _fade_seconds()
	if seconds <= 0.0 or not _overlay.visible:
		_clear()
		return
	_stop_fade()
	_fade = create_tween()
	_fade.tween_property(_overlay, "color:a", 0.0, seconds * _overlay.color.a)
	# Not awaited: a change or a cover that takes over kills this fade, and a
	# killed tween never finishes.
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
	if _covering or _held:
		return
	_stop_fade()
	_overlay.color.a = 0.0
	_overlay.visible = false
	cleared.emit()
