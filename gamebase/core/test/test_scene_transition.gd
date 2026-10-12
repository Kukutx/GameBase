extends GutTest

## The fade every location change goes through (`GameSceneTransition`): one
## change covers the screen at a time, a change asked for while the screen
## clears after the last one starts at once, and a cutscene's cover holds the
## screen through a change until it is given back.

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
	await transition.wait_until_clear()

func test_a_change_while_the_screen_clears_starts_at_once() -> void:
	var transition := _transition()
	assert_true(transition.change_scene(_scene_path))
	await get_tree().scene_changed
	# The screen clears after the scene opened; a travel that follows at once
	# (a collapse right after arriving) is not refused.
	assert_true(transition.change_scene(_scene_path))
	await get_tree().scene_changed
	await transition.wait_until_clear()
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
	await transition.wait_until_clear()
	assert_false((transition.get_node("FadeOverlay") as ColorRect).visible)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_a_cover_holds_the_screen_until_it_is_uncovered() -> void:
	var transition := _transition()
	assert_true(await transition.cover())
	var overlay := transition.get_node("FadeOverlay") as ColorRect
	assert_true(overlay.visible)
	assert_eq(overlay.color.a, 1.0)
	assert_true(transition.is_covered())
	assert_false(transition.is_clear())
	assert_false(await transition.cover(), "the screen is covered already")
	watch_signals(transition)
	assert_true(transition.change_scene(_scene_path), "a cutscene moves the player under its cover")
	await _until_the_scene_opened(transition)
	assert_eq(get_tree().current_scene.scene_file_path, _scene_path)
	assert_eq(overlay.color.a, 1.0, "the change leaves the screen covered")
	await transition.uncover()
	assert_true(transition.is_clear())
	assert_signal_emit_count(transition, "cleared", 1)
	assert_false(overlay.visible)

func test_a_cover_taken_during_a_change_keeps_the_screen_covered_after_it() -> void:
	var transition := _transition()
	var overlay := transition.get_node("FadeOverlay") as ColorRect
	assert_true(transition.change_scene(_scene_path))
	assert_true(await transition.cover(), "the change's own fade covers it")
	await _until_the_scene_opened(transition)
	assert_eq(overlay.color.a, 1.0)
	await transition.uncover()
	assert_true(transition.is_clear())

func test_a_cover_taken_as_the_scene_opens_keeps_the_screen_covered() -> void:
	var transition := _transition()
	var overlay := transition.get_node("FadeOverlay") as ColorRect
	assert_true(transition.change_scene(_scene_path))
	# The opening scene covers the screen for its intro on its first frame.
	await get_tree().scene_changed
	assert_true(await transition.cover())
	await _until_the_scene_opened(transition)
	assert_eq(overlay.color.a, 1.0, "the change did not clear the intro's cover")
	assert_true(overlay.visible)
	await transition.uncover()
	assert_true(transition.is_clear())

func test_a_cover_is_given_back_when_its_holder_leaves_the_tree() -> void:
	var transition := _transition()
	var cutscene := Node.new()
	add_child(cutscene)
	assert_true(await transition.cover(cutscene))
	cutscene.free()
	assert_false(transition.is_covered())
	await transition.wait_until_clear()
	assert_true(transition.is_clear())

func test_a_reset_gives_back_the_cover_at_once() -> void:
	var transition := _transition()
	assert_true(await transition.cover())
	transition.reset()
	assert_true(transition.is_clear())
	assert_true(await transition.cover(), "the screen can be covered again")
	await transition.uncover()

func test_an_uncover_while_the_screen_covers_stops_the_cover() -> void:
	var transition := _transition()
	var covered: Array[bool] = []
	var cover := func() -> void: covered.append(await transition.cover())
	cover.call()
	await transition.uncover()
	assert_true(transition.is_clear())
	await get_tree().process_frame
	assert_eq(covered, [false] as Array[bool], "the cover ended before the screen was covered")

func test_with_reduced_motion_a_cover_is_at_once() -> void:
	GameSettings.reduced_motion = true
	var transition := _transition()
	assert_true(await transition.cover())
	assert_eq((transition.get_node("FadeOverlay") as ColorRect).color.a, 1.0)
	await transition.uncover()
	assert_true(transition.is_clear())

# Waits until the change under way has opened its scene and had its first
# frame, when the screen would start to clear.
func _until_the_scene_opened(transition: GameSceneTransition) -> void:
	while transition.is_covering():
		await get_tree().process_frame
	for _frame: int in 3:
		await get_tree().process_frame

func _transition() -> GameSceneTransition:
	var transition := GameSceneTransition.new()
	transition.fade_seconds = 0.02
	add_child_autofree(transition)
	return transition
