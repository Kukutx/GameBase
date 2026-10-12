extends GutTest

## The fade every location change goes through (`GameSceneTransition`): one
## change covers the screen at a time, and a change asked for while the screen
## clears after the last one starts at once.

const TEST_DIRECTORY := "user://test_scene_transition"

var _scene_path := TEST_DIRECTORY.path_join("fixture_room.tscn")
var _reduced_motion := false

func before_each() -> void:
	_reduced_motion = GameSettings.reduced_motion
	GameSettings.reduced_motion = false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(TEST_DIRECTORY))
	var root := Node2D.new()
	root.name = "FixtureRoom"
	var scene := PackedScene.new()
	scene.pack(root)
	root.free()
	assert_eq(ResourceSaver.save(scene, _scene_path), OK)

func after_each() -> void:
	GameSettings.reduced_motion = _reduced_motion
	var current := get_tree().current_scene
	if current != null and current.scene_file_path == _scene_path:
		get_tree().unload_current_scene()
	if FileAccess.file_exists(_scene_path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(_scene_path))

func test_one_change_covers_the_screen_at_a_time() -> void:
	var transition := _transition()
	assert_true(transition.change_scene(_scene_path))
	assert_true(transition.is_covering())
	assert_false(transition.change_scene(_scene_path), "the screen is covering for the first change")
	await get_tree().scene_changed
	assert_false(transition.is_covering())
	assert_eq(get_tree().current_scene.scene_file_path, _scene_path)

func test_a_change_while_the_screen_clears_starts_at_once() -> void:
	var transition := _transition()
	assert_true(transition.change_scene(_scene_path))
	await get_tree().scene_changed
	# The screen clears after the scene opened; a travel that follows at once
	# (a collapse right after arriving) is not refused.
	assert_true(transition.change_scene(_scene_path))
	await get_tree().scene_changed
	await _wait_until_clear(transition)
	assert_false(transition.is_covering())
	assert_false((transition.get_node("FadeOverlay") as ColorRect).visible)

func test_a_change_without_a_scene_is_refused() -> void:
	var transition := _transition()
	assert_false(transition.change_scene(""))
	assert_false(transition.is_covering())

func test_a_resource_that_is_no_scene_fails_and_clears_the_screen() -> void:
	var path := TEST_DIRECTORY.path_join("not_a_scene.tres")
	assert_eq(ResourceSaver.save(Theme.new(), path), OK)
	var transition := _transition()
	watch_signals(transition)
	assert_true(transition.change_scene(path), "the load starts; what it gives shows once it is done")
	await wait_for_signal(transition.scene_change_failed, 2.0)
	assert_signal_emitted_with_parameters(transition, "scene_change_failed", [path])
	assert_push_warning("Transition: scene change failed")
	assert_false(transition.is_covering())
	assert_false((transition.get_node("FadeOverlay") as ColorRect).visible)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _transition() -> GameSceneTransition:
	var transition := GameSceneTransition.new()
	transition.fade_seconds = 0.02
	add_child_autofree(transition)
	return transition

func _wait_until_clear(transition: GameSceneTransition) -> void:
	var overlay := transition.get_node("FadeOverlay") as ColorRect
	for frame in range(120):
		if not overlay.visible:
			return
		await get_tree().process_frame
