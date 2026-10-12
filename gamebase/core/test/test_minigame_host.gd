extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const MINIGAME := &"fixture_target"

## A minigame the test plays itself: it keeps the settings it was given and
## ends when the test finishes it. It needs a round at least.
class _FixtureMiniGame:
	extends MiniGame

	var settings: Dictionary = {}

	func setup(given: Dictionary) -> void:
		settings = given

	func find_settings_problems(given: Dictionary, _registry: ContentRegistry) -> PackedStringArray:
		var problems := PackedStringArray()
		if int(given.get("rounds", 1)) < 1:
			problems.append("plays %s rounds, fewer than one" % given["rounds"])
		return problems

func before_each() -> void:
	var minigame := _FixtureMiniGame.new()
	var scene := PackedScene.new()
	scene.pack(minigame)
	minigame.free()
	var definition := MiniGameDefinition.new()
	definition.id = MINIGAME
	definition.scene = scene
	definition.settings = {"difficulty": 1, "rounds": 3}
	ContentFixture.use(self, [definition])

func after_each() -> void:
	# GUT frees the fixture content only after this hook.
	ContentRegistry.active = ContentDB
	MiniGameHost.cancel()
	InputLock.clear()

func _active_minigame() -> _FixtureMiniGame:
	return MiniGameHost.get("_active") as _FixtureMiniGame

func test_ending_the_player_s_activities_cancels_the_minigame() -> void:
	var outcome := {}
	var runner := func() -> void:
		outcome["result"] = await MiniGameHost.run(MINIGAME)
	runner.call()
	assert_true(MiniGameHost.is_running())
	# Passing out or a load ends what the player is doing.
	GameSession.end_activities()
	var result := outcome.get("result") as MiniGameResult
	assert_not_null(result)
	assert_true(result.cancelled)
	assert_false(MiniGameHost.is_running())
	assert_false(InputLock.is_held(&"minigame"))

func test_the_fixture_minigame_is_valid_content_and_the_minigame_checks_its_settings() -> void:
	var definition := MiniGameDefinition.find(MINIGAME)
	assert_eq(definition.find_problems(ContentRegistry.active), PackedStringArray())
	definition.settings["rounds"] = 0
	assert_eq(definition.find_problems(ContentRegistry.active), PackedStringArray(["plays 0 rounds, fewer than one"]))

func test_a_cancel_soon_after_one_that_asked_gives_the_minigame_up() -> void:
	var minigame := _FixtureMiniGame.new()
	assert_false(minigame.confirm_give_up(), "the first only asks")
	assert_true(minigame.confirm_give_up())
	assert_false(minigame.confirm_give_up(), "the next asks anew")
	assert_eq(minigame.get_give_up_prompt(), "Cancel again to give up.")
	assert_eq([minigame.get_outcome_text(true), minigame.get_outcome_text(false)], ["Victory!", "Defeat."])
	minigame.free()

func test_host_pauses_the_world_blocks_saving_and_restores_both() -> void:
	var outcome := {}
	var runner := func() -> void:
		outcome["result"] = await MiniGameHost.run(MINIGAME, {"rounds": 1, "seed": 4})
	runner.call()
	assert_true(MiniGameHost.is_running())
	assert_eq(MiniGameHost.get_active_id(), MINIGAME)
	assert_true(get_tree().paused)
	assert_eq(MiniGameHost.call("_save_block_reason"), "Finish the minigame before saving")
	var minigame := _active_minigame()
	assert_not_null(minigame)
	assert_eq(minigame.settings, {"difficulty": 1, "rounds": 1, "seed": 4}, "the caller's context overrides the definition's settings")
	minigame.finish(MiniGameResult.won(3))
	await get_tree().process_frame
	var result := outcome.get("result") as MiniGameResult
	assert_not_null(result)
	assert_true(result.success)
	assert_eq(result.score, 3)
	assert_false(MiniGameHost.is_running())
	assert_false(get_tree().paused)
	assert_eq(MiniGameHost.call("_save_block_reason"), "")

func test_the_minigame_stands_still_while_a_lock_is_over_it() -> void:
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var minigame := _active_minigame()
	assert_true(get_tree().paused)
	assert_true(minigame.can_process(), "it runs over the paused world")
	assert_true(minigame.has_input())
	InputLock.lock(&"fixture_menu", true)
	assert_false(minigame.can_process(), "nothing in it moves under a menu")
	assert_false(minigame.has_input())
	InputLock.unlock(&"fixture_menu")
	assert_true(minigame.can_process(), "and it goes on once the menu closes")
	assert_true(minigame.has_input())

func test_the_pause_menu_opens_over_a_minigame_when_the_window_loses_focus() -> void:
	(func() -> void: await MiniGameHost.run(MINIGAME)).call()
	var minigame := _active_minigame()
	var menu := (load("res://gamebase/core/ui/pause_menu.tscn") as PackedScene).instantiate() as PauseMenu
	add_child_autofree(menu)
	assert_gt(menu.layer, MiniGameHostService.LAYER, "the menu shows over the minigame")
	assert_gt(menu.settings_menu.layer, menu.layer)
	assert_true(GameSettings.pause_on_focus_loss)
	menu.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(menu.visible)
	assert_false(minigame.can_process(), "the minigame stands still under it")
	menu.close()
	assert_true(minigame.can_process())
	assert_true(MiniGameHost.is_running(), "closing the menu goes back to the minigame")

func test_a_second_run_while_one_is_running_fails_at_once() -> void:
	var runner := func() -> void:
		await MiniGameHost.run(MINIGAME)
	runner.call()
	var busy: MiniGameResult = await MiniGameHost.run(MINIGAME)
	assert_false(busy.success)
	assert_eq(String(busy.data.get("reason", "")), "busy")
	MiniGameHost.cancel()
	await get_tree().process_frame
	assert_false(MiniGameHost.is_running())
