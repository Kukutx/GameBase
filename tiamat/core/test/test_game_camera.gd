extends GutTest

## The view of the world (`GameCamera`): it shows where the player was put at
## once, keeps inside the location's bounds (`CameraBounds`) and shows a map
## smaller than the view whole in its middle, zooms, and shakes and settles
## back; with reduced motion nothing shakes and a zoom is at once.

var _reduced_motion := false

func before_each() -> void:
	_reduced_motion = GameSettings.reduced_motion
	GameSettings.reduced_motion = false

func after_each() -> void:
	GameSettings.reduced_motion = _reduced_motion

func test_the_view_is_at_once_where_the_player_was_put() -> void:
	var camera := _camera()
	var followed := camera.get_parent() as Node2D
	await get_tree().process_frame
	followed.global_position = Vector2(900, -400)
	await get_tree().process_frame
	assert_ne(camera.get_screen_center_position(), Vector2(900, -400), "walked there, the view eases after")
	followed.global_position = Vector2(-1200, 300)
	GameCamera.snap_all(get_tree())
	assert_eq(camera.get_screen_center_position(), Vector2(-1200, 300), "put there, it is there at once")

func test_the_view_keeps_inside_the_bounds_and_shows_a_small_map_in_its_middle() -> void:
	var camera := _camera()
	var view := camera.get_viewport_rect().size
	var bounds := _bounds(Rect2(-1000, -800, 2000, 1600))
	assert_eq([camera.limit_left, camera.limit_top, camera.limit_right, camera.limit_bottom], [-1000, -800, 1000, 800], "bounds that come after the camera take it")
	(camera.get_parent() as Node2D).global_position = Vector2(990, 0)
	camera.snap()
	assert_almost_eq(camera.get_screen_center_position().x, 1000.0 - view.x / 2.0, 0.5, "no farther than the edge")
	bounds.size = view / 4.0
	bounds.position = Vector2(100, 100)
	camera.use_bounds(bounds)
	camera.snap()
	# The limits are whole pixels.
	assert_almost_eq(camera.get_screen_center_position(), Vector2(100, 100) + view / 8.0, Vector2.ONE, "a map smaller than the view shows in its middle")
	var later := _camera(Vector2.ZERO, false)
	assert_eq([later.limit_left, later.limit_right], [camera.limit_left, camera.limit_right], "a camera that comes after the bounds takes them")
	camera.use_bounds(null)
	assert_eq(camera.limit_right, CameraBounds.UNBOUNDED)
	assert_eq(bounds.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the bounds take no clicks")

func test_the_zoom_eases_to_its_level_and_is_at_once_with_reduced_motion() -> void:
	var camera := _camera()
	camera.zoom_to(2.0, 0.05)
	assert_eq(camera.zoom, Vector2.ONE, "it eases")
	await wait_seconds(0.15)
	assert_eq(camera.zoom, Vector2(2, 2))
	GameSettings.reduced_motion = true
	camera.zoom_to(0.5)
	assert_eq(camera.zoom, Vector2(0.5, 0.5))

func test_the_view_shakes_and_settles_back() -> void:
	var camera := _camera(Vector2(3, 4))
	assert_true(GameCamera.shake_view(camera, 4.0, 0.05))
	assert_true(camera.is_shaking())
	await get_tree().process_frame
	assert_true(GameCamera.shake_view(camera, 4.0, 0.05), "a shake while one runs takes over")
	await wait_seconds(0.2)
	assert_false(camera.is_shaking())
	assert_eq(camera.offset, Vector2(3, 4), "back where it rested")

func test_nothing_shakes_with_reduced_motion_or_without_a_game_camera() -> void:
	var camera := _camera(Vector2(3, 4))
	GameSettings.reduced_motion = true
	assert_false(GameCamera.shake_view(camera))
	assert_eq(camera.offset, Vector2(3, 4))
	GameSettings.reduced_motion = false
	assert_false(camera.shake(0.0))
	var outside := Node.new()
	assert_false(GameCamera.shake_view(outside), "a node outside the tree has no view")
	outside.free()
	var plain := Camera2D.new()
	add_child_autofree(plain)
	plain.make_current()
	assert_false(GameCamera.shake_view(plain), "only a game camera shakes")

# A game camera on a node it follows, the view's camera.
func _camera(rest_offset := Vector2.ZERO, current := true) -> GameCamera:
	var followed := Node2D.new()
	var camera := GameCamera.new()
	camera.offset = rest_offset
	followed.add_child(camera)
	add_child_autofree(followed)
	if current:
		camera.make_current()
	return camera

func _bounds(rect: Rect2) -> CameraBounds:
	var bounds := CameraBounds.new()
	bounds.position = rect.position
	bounds.size = rect.size
	add_child_autofree(bounds)
	return bounds
