extends GutTest

func test_fish_data_filters_location_season_and_time() -> void:
	var trout := ContentDB.get_fish(&"river_trout")
	assert_not_null(trout)
	assert_true(trout.is_available(&"riverside_town", 1, 8 * 60, "Clear"))
	assert_false(trout.is_available(&"harbor_town", 1, 8 * 60, "Clear"))
	assert_false(trout.is_available(&"riverside_town", 29, 8 * 60, "Clear"))
	assert_false(trout.is_available(&"riverside_town", 1, 21 * 60, "Clear"))

func test_fishing_service_uses_location_specific_pools() -> void:
	var previous_day := WorldClock.day
	var previous_minute := WorldClock.minute_of_day
	WorldClock.set_time(1, 13 * 60)
	var service := FishingService.new()
	add_child_autofree(service)
	var river := service.get_available_fish(&"riverside_town")
	var harbor := service.get_available_fish(&"harbor_town")
	assert_true(river.any(func(f: FishData) -> bool: return f.id == &"river_carp"))
	assert_false(river.any(func(f: FishData) -> bool: return f.id == &"sardine"))
	assert_true(harbor.any(func(f: FishData) -> bool: return f.id == &"sardine"))
	assert_false(harbor.any(func(f: FishData) -> bool: return f.id == &"river_carp"))
	WorldClock.set_time(previous_day, previous_minute)

func test_storm_eel_requires_storm_weather() -> void:
	var eel := ContentDB.get_fish(&"storm_eel")
	assert_not_null(eel)
	assert_true(eel.is_available(&"harbor_town", 1, 12 * 60, "Storm"))
	assert_false(eel.is_available(&"harbor_town", 1, 12 * 60, "Clear"))
	assert_false(eel.is_available(&"riverside_town", 1, 12 * 60, "Storm"))

func test_fishing_sequence_round_trips() -> void:
	var source := FishingService.new()
	add_child_autofree(source)
	source.cast_count = 9
	var restored := FishingService.new()
	add_child_autofree(restored)
	restored.load_save_data(source.to_save_data())
	assert_eq(restored.cast_count, 9)

func test_fishing_state_machine_waits_bites_and_reels() -> void:
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
	service.bite_delay_range = Vector2(0.01, 0.01)
	service.bite_window = 1.0
	assert_true(service.start_cast(&"riverside_town", 0))
	assert_true(service.is_active())
	assert_eq(service.cast_state, FishingService.CastState.WAITING)
	service._process(0.06)
	assert_eq(service.cast_state, FishingService.CastState.BITE)
	assert_true(service.reel_in())
	assert_false(service.is_active())
	assert_eq(service.cast_state, FishingService.CastState.IDLE)
	assert_eq(InventoryState.get_quantity(&"river_trout") + InventoryState.get_quantity(&"river_carp"), 1)

	InventoryState.load_save_data(inventory_snapshot)
	PlayerState.load_save_data(player_snapshot)
	Hotbar.load_save_data(hotbar_snapshot)
	QuestState.load_save_data(quest_snapshot)
	Skills.load_save_data(skill_snapshot)
	WorldClock.set_time(old_day, old_minute)

func test_fishing_blocks_energy_and_item_signal_reentrancy() -> void:
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
	service.bite_delay_range = Vector2(0.01, 0.01)
	service.bite_window = 1.0

	var energy_before := PlayerState.energy
	var start_observed := {"entered": false, "inner_result": true}
	var energy_listener := func(_current: int, _maximum: int) -> void:
		if bool(start_observed["entered"]):
			return
		start_observed["entered"] = true
		start_observed["inner_result"] = service.start_cast(&"riverside_town", 4)
	PlayerState.energy_changed.connect(energy_listener)
	assert_true(service.start_cast(&"riverside_town", 4))
	if PlayerState.energy_changed.is_connected(energy_listener):
		PlayerState.energy_changed.disconnect(energy_listener)
	assert_true(bool(start_observed["entered"]))
	assert_false(bool(start_observed["inner_result"]))
	assert_eq(PlayerState.energy, energy_before - 4)

	service._process(0.06)
	assert_eq(service.cast_state, FishingService.CastState.BITE)
	var pending := service.get("_pending_fish") as FishData
	assert_not_null(pending)
	if pending != null:
		var caught_item_id := pending.item_id
		var reel_observed := {"entered": false, "inner_result": true}
		var item_listener := func(item_id: StringName, _quantity: int) -> void:
			if item_id != caught_item_id or bool(reel_observed["entered"]):
				return
			reel_observed["entered"] = true
			reel_observed["inner_result"] = service.reel_in()
		InventoryState.item_added.connect(item_listener)
		assert_true(service.reel_in())
		if InventoryState.item_added.is_connected(item_listener):
			InventoryState.item_added.disconnect(item_listener)
		assert_true(bool(reel_observed["entered"]))
		assert_false(bool(reel_observed["inner_result"]))
		assert_eq(InventoryState.get_quantity(caught_item_id), 1)
		assert_eq(service.cast_state, FishingService.CastState.IDLE)

	InventoryState.load_save_data(inventory_snapshot)
	PlayerState.load_save_data(player_snapshot)
	Hotbar.load_save_data(hotbar_snapshot)
	QuestState.load_save_data(quest_snapshot)
	Skills.load_save_data(skill_snapshot)
	WorldClock.set_time(old_day, old_minute)
