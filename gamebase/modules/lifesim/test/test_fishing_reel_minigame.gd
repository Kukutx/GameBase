extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const REEL := &"fixture_reel"

func before_each() -> void:
	var definition := MiniGameDefinition.new()
	definition.id = REEL
	definition.scene = load("res://gamebase/modules/lifesim/fishing/fishing_reel_minigame.tscn") as PackedScene
	ContentFixture.use(self, [definition])

func after_each() -> void:
	# GUT frees the fixture content only after this hook.
	ContentRegistry.active = ContentDB
	MiniGameHost.cancel()
	get_tree().paused = false

func _active_reel() -> FishingReelMiniGame:
	return MiniGameHost.get("_active") as FishingReelMiniGame

func test_hitting_the_zone_wins_with_the_attempts_left() -> void:
	var outcome := {}
	var runner := func() -> void:
		outcome["result"] = await MiniGameHost.run(REEL, {"difficulty": 1, "seed": 4})
	runner.call()
	var reel := _active_reel()
	assert_not_null(reel)
	reel.marker = reel.zone_start + reel.zone_width * 0.5
	assert_true(reel.press())
	await get_tree().process_frame
	var result := outcome.get("result") as MiniGameResult
	assert_not_null(result)
	assert_true(result.success)
	assert_eq(result.score, 3)

func test_misses_use_up_attempts_and_lose() -> void:
	var outcome := {}
	var runner := func() -> void:
		outcome["result"] = await MiniGameHost.run(REEL, {"difficulty": 10, "attempts": 2, "seed": 1})
	runner.call()
	var reel := _active_reel()
	reel.marker = 0.0 if reel.zone_start > 0.05 else 1.0
	assert_false(reel.press())
	assert_true(MiniGameHost.is_running())
	assert_false(reel.press())
	await get_tree().process_frame
	var result := outcome.get("result") as MiniGameResult
	assert_false(result.success)
	assert_false(result.cancelled)

func test_harder_fish_get_a_smaller_faster_zone() -> void:
	var easy := FishingReelMiniGame.new()
	var hard := FishingReelMiniGame.new()
	easy.setup({"difficulty": 1})
	hard.setup({"difficulty": 9})
	assert_gt(easy.zone_width, hard.zone_width)
	assert_lt(easy.marker_speed, hard.marker_speed)
	var buffed := FishingReelMiniGame.new()
	buffed.setup({"difficulty": 9, "zone_scale": 1.5})
	assert_gt(buffed.zone_width, hard.zone_width)
	for reel: FishingReelMiniGame in [easy, hard, buffed]:
		reel.free()

func test_marker_bounces_inside_the_bar() -> void:
	var reel := FishingReelMiniGame.new()
	reel.setup({"difficulty": 5})
	for step: int in 200:
		reel.advance(0.037)
		assert_between(reel.marker, 0.0, 1.0)
	reel.free()
