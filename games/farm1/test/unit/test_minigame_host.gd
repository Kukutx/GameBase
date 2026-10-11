extends GutTest

const REEL := &"fishing_reel"

func after_each() -> void:
	MiniGameHost.cancel()
	InputLock.clear()

func _active_reel() -> FishingReelMiniGame:
	return MiniGameHost.get("_active") as FishingReelMiniGame

func test_the_reel_minigame_is_registered_content() -> void:
	var definition := MiniGameDefinition.find(REEL)
	assert_not_null(definition)
	var root := definition.scene.instantiate()
	assert_true(root is MiniGame, "the scene root extends MiniGame")
	root.free()

func test_the_reel_gives_three_tries() -> void:
	var runner := func() -> void:
		await MiniGameHost.run(REEL, {"difficulty": 1, "seed": 4})
	runner.call()
	var reel := _active_reel()
	assert_not_null(reel)
	if reel != null:
		assert_eq(reel.attempts_left, 3)

func test_winning_the_reel_lands_the_biting_fish() -> void:
	var old_day := WorldClock.day
	var old_minute := WorldClock.minute_of_day
	var inventory_snapshot := InventoryState.to_save_data()
	var player_snapshot := PlayerState.to_save_data()
	var hotbar_snapshot := Hotbar.to_save_data()
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
	Hotbar.load_save_data(hotbar_snapshot)
	QuestState.load_save_data(quest_snapshot)
	Skills.load_save_data(skill_snapshot)
	WorldClock.set_time(old_day, old_minute)
