extends GutTest

const REEL := &"fishing_reel"

func after_each() -> void:
	MiniGameHost.cancel()
	get_tree().paused = false

func _active_reel() -> FishingReelMiniGame:
	return MiniGameHost.get("_active") as FishingReelMiniGame

func test_the_reel_minigame_is_registered_content() -> void:
	var definition := ContentDB.get_minigame(REEL)
	assert_not_null(definition)
	var root := definition.scene.instantiate()
	assert_true(root is MiniGame, "the scene root extends MiniGame")
	root.free()

func test_host_pauses_the_world_blocks_saving_and_restores_both() -> void:
	var outcome := {}
	var runner := func() -> void:
		outcome["result"] = await MiniGameHost.run(REEL, {"difficulty": 1, "seed": 4})
	runner.call()
	assert_true(MiniGameHost.is_running())
	assert_eq(MiniGameHost.get_active_id(), REEL)
	assert_true(get_tree().paused)
	assert_eq(MiniGameHost.call("_save_block_reason"), "Finish the minigame before saving")
	var reel := _active_reel()
	assert_not_null(reel)
	reel.marker = reel.zone_start + reel.zone_width * 0.5
	assert_true(reel.press())
	await get_tree().process_frame
	var result := outcome.get("result") as MiniGameResult
	assert_not_null(result)
	assert_true(result.success)
	assert_eq(result.score, 3)
	assert_false(MiniGameHost.is_running())
	assert_false(get_tree().paused)
	assert_eq(MiniGameHost.call("_save_block_reason"), "")

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

func test_a_second_run_while_one_is_running_fails_at_once() -> void:
	var runner := func() -> void:
		await MiniGameHost.run(REEL)
	runner.call()
	var busy: MiniGameResult = await MiniGameHost.run(REEL)
	assert_false(busy.success)
	assert_eq(String(busy.data.get("reason", "")), "busy")
	MiniGameHost.cancel()
	await get_tree().process_frame
	assert_false(MiniGameHost.is_running())

func test_winning_the_reel_lands_the_biting_fish() -> void:
	var old_day := WorldClock.day
	var old_minute := WorldClock.minute_of_day
	var inventory_snapshot := InventoryState.to_save_data()
	var player_snapshot := PlayerState.to_save_data()
	var quest_snapshot := QuestState.to_save_data()
	var skill_snapshot := Skills.to_save_data()
	WorldClock.set_time(1, 13 * 60)
	InventoryState.clear()
	PlayerState.restore_full_energy()
	var service := FishingService.new()
	add_child_autofree(service)
	service.reel_minigame_id = REEL
	service.bite_delay_range = Vector2(0.01, 0.01)
	assert_true(service.start_cast(&"riverside_town", 0))
	service._process(0.06)
	assert_eq(service.cast_state, FishingService.CastState.BITE)
	var outcome := {}
	var runner := func() -> void:
		outcome["caught"] = await service.reel_in_with_minigame()
	runner.call()
	var reel := _active_reel()
	reel.marker = reel.zone_start + reel.zone_width * 0.5
	reel.press()
	await get_tree().process_frame
	assert_true(bool(outcome.get("caught", false)))
	assert_eq(service.cast_state, FishingService.CastState.IDLE)
	assert_eq(InventoryState.get_quantity(&"river_trout") + InventoryState.get_quantity(&"river_carp"), 1)
	InventoryState.load_save_data(inventory_snapshot)
	PlayerState.load_save_data(player_snapshot)
	QuestState.load_save_data(quest_snapshot)
	Skills.load_save_data(skill_snapshot)
	WorldClock.set_time(old_day, old_minute)
