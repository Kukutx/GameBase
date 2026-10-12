class_name ScreenShake
extends RefCounted

## Shakes the view for a moment (a hit, a blast): the camera of the viewport a
## node is in (`Viewport.get_camera_2d()`) jitters around where it was and
## settles back. Nothing shakes with reduced motion (`GameSettings`). A shake
## while another runs replaces it from the camera's resting place.

const _REST_META := &"gamebase_shake_rest"
const _TWEEN_META := &"gamebase_shake_tween"

## Shakes the camera of `node`'s viewport by up to `strength` pixels for
## `seconds`. False when nothing shakes: reduced motion, no camera, no shake.
static func shake(node: Node, strength := 3.0, seconds := 0.2) -> bool:
	if GameSettings.reduced_motion or node == null or not node.is_inside_tree() or strength <= 0.0 or seconds <= 0.0:
		return false
	var camera := node.get_viewport().get_camera_2d()
	if camera == null:
		return false
	var running := _running(camera)
	if running != null:
		running.kill()
	else:
		camera.set_meta(_REST_META, camera.offset)
	var rest: Vector2 = camera.get_meta(_REST_META)
	# The jitter fades out as the shake runs; how it looks needs no seeded
	# randomness.
	var jitter := func(left: float) -> void:
		camera.offset = rest + Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * strength * left
	var settle := func() -> void:
		camera.offset = rest
		camera.remove_meta(_TWEEN_META)
	var tween := camera.create_tween()
	camera.set_meta(_TWEEN_META, tween)
	tween.tween_method(jitter, 1.0, 0.0, seconds)
	tween.tween_callback(settle)
	return true

## Whether `camera` is shaking.
static func is_shaking(camera: Camera2D) -> bool:
	return camera != null and _running(camera) != null

# The shake running on `camera`, or null.
static func _running(camera: Camera2D) -> Tween:
	if not camera.has_meta(_TWEEN_META):
		return null
	var running: Variant = camera.get_meta(_TWEEN_META)
	return running as Tween if running is Tween and (running as Tween).is_valid() else null
