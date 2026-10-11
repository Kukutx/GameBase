extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

var _clock_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _world_snapshot: Dictionary
var _skill_snapshot: Dictionary

func before_each() -> void:
	_clock_snapshot = WorldClock.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	_skill_snapshot = Skills.to_save_data()
	ContentFixture.use(self, _fixture_content())

func after_each() -> void:
	# GUT frees the fixture content only after this method: restore the
	# services with the game's content, which their snapshots name.
	ContentRegistry.active = ContentDB
	WorldClock.load_save_data(_clock_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	WorldState.load_save_data(_world_snapshot)
	Skills.load_save_data(_skill_snapshot)

func test_fish_data_filters_location_season_and_time() -> void:
	var trout := FishData.find(&"fixture_trout")
	assert_true(trout.is_available(&"fixture_river", 1, 8 * 60, "Clear"))
	assert_false(trout.is_available(&"fixture_harbor", 1, 8 * 60, "Clear"))
	assert_false(trout.is_available(&"fixture_river", 29, 8 * 60, "Clear"))
	assert_false(trout.is_available(&"fixture_river", 1, 21 * 60, "Clear"))

func test_fishing_service_uses_location_specific_pools() -> void:
	WorldClock.set_time(1, 13 * 60)
	var service := FishingService.new()
	add_child_autofree(service)
	var river := service.get_available_fish(&"fixture_river")
	var harbor := service.get_available_fish(&"fixture_harbor")
	assert_true(river.any(func(f: FishData) -> bool: return f.id == &"fixture_carp"))
	assert_false(river.any(func(f: FishData) -> bool: return f.id == &"fixture_sardine"))
	assert_true(harbor.any(func(f: FishData) -> bool: return f.id == &"fixture_sardine"))
	assert_false(harbor.any(func(f: FishData) -> bool: return f.id == &"fixture_carp"))

func test_storm_fish_requires_storm_weather() -> void:
	var eel := FishData.find(&"fixture_eel")
	assert_true(eel.is_available(&"fixture_harbor", 1, 12 * 60, "Storm"))
	assert_false(eel.is_available(&"fixture_harbor", 1, 12 * 60, "Clear"))
	assert_false(eel.is_available(&"fixture_river", 1, 12 * 60, "Storm"))

func test_fishing_sequence_round_trips() -> void:
	var source := FishingService.new()
	add_child_autofree(source)
	source.cast_count = 9
	var restored := FishingService.new()
	add_child_autofree(restored)
	restored.load_save_data(source.to_save_data())
	assert_eq(restored.cast_count, 9)

func test_fishing_state_machine_waits_bites_and_reels() -> void:
	WorldClock.set_time(1, 13 * 60)
	InventoryState.clear()
	PlayerState.restore_full_energy()

	var service := FishingService.new()
	add_child_autofree(service)
	service.bite_delay_range = Vector2(0.01, 0.01)
	service.bite_window = 1.0
	assert_true(service.start_cast(&"fixture_river", 0))
	assert_true(service.is_active())
	assert_eq(service.cast_state, FishingService.CastState.WAITING)
	service._process(0.06)
	assert_eq(service.cast_state, FishingService.CastState.BITE)
	assert_true(service.reel_in())
	assert_false(service.is_active())
	assert_eq(service.cast_state, FishingService.CastState.IDLE)
	assert_eq(InventoryState.get_quantity(&"fixture_trout") + InventoryState.get_quantity(&"fixture_carp"), 1)

func test_fishing_blocks_energy_and_item_signal_reentrancy() -> void:
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
		start_observed["inner_result"] = service.start_cast(&"fixture_river", 4)
	PlayerState.energy_changed.connect(energy_listener)
	assert_true(service.start_cast(&"fixture_river", 4))
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

# A river with a trout (spring and autumn, 6:00 to 20:00, clear or rainy
# weather) and a carp that bites any time; a harbor with a sardine that bites
# any time and an eel that bites only in storms.
func _fixture_content() -> Array:
	return [
		_item(&"fixture_trout"),
		_item(&"fixture_carp"),
		_item(&"fixture_sardine"),
		_item(&"fixture_eel"),
		_fish(&"fixture_trout", &"fixture_river", PackedStringArray(["Spring", "Autumn"]), 6 * 60, 20 * 60,
			PackedStringArray(["Clear", "Rain"])),
		_fish(&"fixture_carp", &"fixture_river", PackedStringArray(), 0, 24 * 60, PackedStringArray()),
		_fish(&"fixture_sardine", &"fixture_harbor", PackedStringArray(), 0, 24 * 60, PackedStringArray()),
		_fish(&"fixture_eel", &"fixture_harbor", PackedStringArray(["Spring", "Summer", "Autumn"]), 8 * 60, 23 * 60,
			PackedStringArray(["Storm"])),
	]

func _item(id: StringName) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	item.tags = PackedStringArray(["fish"])
	return item

func _fish(id: StringName, location_id: StringName, seasons: PackedStringArray, start_minute: int, end_minute: int,
		allowed_weather: PackedStringArray) -> FishData:
	var fish := FishData.new()
	fish.id = id
	fish.item_id = id
	fish.locations.assign([location_id])
	fish.seasons = seasons
	fish.start_minute = start_minute
	fish.end_minute = end_minute
	fish.allowed_weather = allowed_weather
	return fish
