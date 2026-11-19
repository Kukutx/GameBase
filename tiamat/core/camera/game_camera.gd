class_name GameCamera
extends Camera2D

## The view of the world, the camera a game puts on its player: it follows its
## parent smoothly, jumps to it at once where the player was put rather than
## walked (`snap()`: a travel's spawn point, a load), keeps inside the bounds
## the location sets (`CameraBounds`), zooms (`zoom_to()`) and shakes for a
## moment (`shake()`, or `shake_view()` from anything in the world: a hit, a
## blast). With reduced motion (`GameSettings`) nothing shakes and a zoom
## takes effect at once.

## The group every game camera is in.
const GROUP := &"game_camera"
## How fast a zoom eases to its level, in seconds.
const ZOOM_SECONDS := 0.25

# The bounds the view keeps inside, in world coordinates; empty for none.
var _bounds := Rect2()
# The size of the visible world the limits were last worked out for.
var _limits_view := Vector2.ZERO
# The offset the view rests at, which a shake jitters around.
var _rest_offset := Vector2.ZERO
var _shake_strength := 0.0
var _shake_seconds := 0.0
var _shake_left := 0.0
var _zoom_tween: Tween

## Shakes the view of the viewport `node` is in by up to `strength` pixels
## for `seconds`. False when nothing shakes: reduced motion, no game camera, no
## shake.
static func shake_view(node: Node, strength := 3.0, seconds := 0.2) -> bool:
	if node == null or not node.is_inside_tree():
		return false
	var camera := node.get_viewport().get_camera_2d() as GameCamera
	return camera != null and camera.shake(strength, seconds)

## Puts every game camera of `tree` on what it follows at once: after the
## player was put somewhere (`WorldTravel.place_player()`).
static func snap_all(tree: SceneTree) -> void:
	for node: Node in tree.get_nodes_in_group(GROUP):
		(node as GameCamera).snap()

func _init() -> void:
	position_smoothing_enabled = true
	position_smoothing_speed = 7.0

func _enter_tree() -> void:
	add_to_group(GROUP)

func _ready() -> void:
	use_bounds(CameraBounds.find_for(self))
	snap()

## Shows where the camera stands at once, without easing there.
func snap() -> void:
	reset_smoothing()
	# Drawn from where it stands now, not from where the last frame left it.
	force_update_scroll()

## Keeps the view inside `bounds`, or lets it go anywhere for null. A map
## smaller than the view shows whole, in the middle of it.
func use_bounds(bounds: CameraBounds) -> void:
	_bounds = bounds.get_world_rect() if bounds != null else Rect2()
	_update_limits()

## Zooms the view to `level` (2 shows everything twice as large), easing there
## over `seconds`.
func zoom_to(level: float, seconds := ZOOM_SECONDS) -> void:
	if _zoom_tween != null and _zoom_tween.is_valid():
		_zoom_tween.kill()
	var target := Vector2.ONE * maxf(level, 0.01)
	if seconds <= 0.0 or GameSettings.reduced_motion or not is_inside_tree():
		zoom = target
		return
	_zoom_tween = create_tween()
	_zoom_tween.tween_property(self, "zoom", target, seconds)

## Shakes the view by up to `strength` pixels for `seconds`, fading out; a
## shake while another runs takes over from the resting offset. False when
## nothing shakes: reduced motion, or no strength or time.
func shake(strength := 3.0, seconds := 0.2) -> bool:
	if GameSettings.reduced_motion or strength <= 0.0 or seconds <= 0.0:
		return false
	if not is_shaking():
		_rest_offset = offset
	_shake_strength = strength
	_shake_seconds = seconds
	_shake_left = seconds
	return true

func is_shaking() -> bool:
	return _shake_left > 0.0

func _process(delta: float) -> void:
	if _limits_view != _get_view_size():
		_update_limits()
	if not is_shaking():
		return
	_shake_left -= delta
	if _shake_left <= 0.0:
		_shake_left = 0.0
		offset = _rest_offset
		return
	# The jitter fades as the shake runs; how it looks needs no seeded
	# randomness.
	var left := _shake_left / _shake_seconds
	offset = _rest_offset + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake_strength * left

# The limits that keep the view inside the bounds at the view's size and zoom
# now.
func _update_limits() -> void:
	if not is_inside_tree():
		return
	var view := _get_view_size()
	_limits_view = view
	if not _bounds.has_area():
		limit_left = -CameraBounds.UNBOUNDED
		limit_top = -CameraBounds.UNBOUNDED
		limit_right = CameraBounds.UNBOUNDED
		limit_bottom = CameraBounds.UNBOUNDED
		return
	var spare := (view - _bounds.size).max(Vector2.ZERO) / 2.0
	var shown := _bounds.grow_individual(spare.x, spare.y, spare.x, spare.y)
	limit_left = floori(shown.position.x)
	limit_top = floori(shown.position.y)
	limit_right = ceili(shown.end.x)
	limit_bottom = ceili(shown.end.y)

# The size of the world the view shows: the viewport's at this zoom.
func _get_view_size() -> Vector2:
	return get_viewport_rect().size / zoom
