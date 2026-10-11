extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const MINIGAME := &"fixture_target"

## A minigame the test plays itself: it keeps the settings it was given and
## ends when the test finishes it.
class _FixtureMiniGame:
	extends MiniGame

	var settings: Dictionary = {}

	func setup(given: Dictionary) -> void:
		settings = given

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
	get_tree().paused = false

func _active_minigame() -> _FixtureMiniGame:
	return MiniGameHost.get("_active") as _FixtureMiniGame

func test_the_fixture_minigame_is_valid_content() -> void:
	assert_eq(MiniGameDefinition.find(MINIGAME).find_problems(ContentRegistry.active), PackedStringArray())

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
