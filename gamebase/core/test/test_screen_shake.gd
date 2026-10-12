extends GutTest

## Shaking the view (`ScreenShake`): the camera jitters and settles back where
## it was, and nothing shakes with reduced motion.

var _reduced_motion := false

func before_each() -> void:
	_reduced_motion = GameSettings.reduced_motion
	GameSettings.reduced_motion = false

func after_each() -> void:
	GameSettings.reduced_motion = _reduced_motion

func test_the_camera_shakes_and_settles_back() -> void:
	var camera := _camera()
	assert_true(ScreenShake.shake(camera, 4.0, 0.05))
	assert_true(ScreenShake.is_shaking(camera))
	await get_tree().process_frame
	assert_true(ScreenShake.shake(camera, 4.0, 0.05), "a shake while one runs takes over")
	await wait_seconds(0.2)
	assert_false(ScreenShake.is_shaking(camera))
	assert_eq(camera.offset, Vector2(3, 4), "back where it rested")

func test_nothing_shakes_with_reduced_motion_or_without_a_camera() -> void:
	var camera := _camera()
	GameSettings.reduced_motion = true
	assert_false(ScreenShake.shake(camera))
	assert_eq(camera.offset, Vector2(3, 4))
	GameSettings.reduced_motion = false
	assert_false(ScreenShake.shake(camera, 0.0))
	var outside := Node.new()
	assert_false(ScreenShake.shake(outside), "a node outside the tree has no view")
	outside.free()

func _camera() -> Camera2D:
	var camera := Camera2D.new()
	camera.offset = Vector2(3, 4)
	add_child_autofree(camera)
	camera.make_current()
	return camera
