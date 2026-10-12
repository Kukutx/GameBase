extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const FARM_PLOT_SCENE := preload("res://gamebase/modules/lifesim/farming/farm_plot.tscn")

var _clock_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _world_snapshot: Dictionary
var _skill_snapshot: Dictionary
var _inventory_slots: int

func before_each() -> void:
	_clock_snapshot = WorldClock.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	_skill_snapshot = Skills.to_save_data()
	_inventory_slots = InventoryState.max_slots
	ContentFixture.use(self, _fixture_content())
	WorldClock.set_time(1, 8 * 60)
	InventoryState.clear()
	PlayerState.reset_new_game()
	Skills.reset_new_game()
	InventoryState.add_item_by_id(&"fixture_hoe", 1)
	InventoryState.add_item_by_id(&"fixture_can", 1)
	InventoryState.add_item_by_id(&"fixture_radish_seeds", 5)

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
	InventoryState.max_slots = _inventory_slots

func test_full_crop_growth_cycle() -> void:
	var plot := _add_plot()

	assert_true(plot.use_item(&"fixture_hoe"))
	assert_true(plot.tilled)
	assert_true(plot.use_item(&"fixture_radish_seeds"))
	assert_eq(plot.crop_id, &"fixture_radish")
	if not plot.watered:
		assert_true(plot.use_item(&"fixture_can"))

	for day in range(2, 6):
		WorldClock.set_time(day, 6 * 60)
		if day < 5 and not plot.watered:
			assert_true(plot.use_item(&"fixture_can"))

	assert_eq(plot.growth_days, 4)
	assert_true(plot.can_harvest())
	plot.interact(null)
	assert_eq(InventoryState.get_quantity(&"fixture_radish"), 1)
	assert_eq(plot.crop_id, &"")

func test_loaded_farm_state_clamps_future_day_and_excess_growth() -> void:
	WorldClock.set_time(10, 8 * 60)
	var crop := CropData.find(&"fixture_radish")
	var plot := _add_plot()
	plot.load_state_data({
		"tilled": true,
		"watered": true,
		"crop_id": "fixture_radish",
		"growth_days": 999999,
		"last_processed_day": 999999,
	}, false)
	assert_eq(plot.growth_days, crop.days_to_mature)
	assert_eq(plot.last_processed_day, 10)
	assert_true(plot.can_harvest())

func test_empty_plot_catchup_handles_extreme_day_jump_without_per_day_iteration() -> void:
	var plot := _add_plot()
	plot.tilled = true
	plot.watered = false
	plot.crop_id = &""
	plot.last_processed_day = 1
	plot.call("_advance_to_day", 1_000_000)
	assert_eq(plot.last_processed_day, 1_000_000)
	assert_eq(plot.crop_id, &"")
	assert_eq(plot.watered, plot.tilled and WeatherState.is_ground_wet(1_000_000))

func test_seasonal_crop_catchup_stops_simulating_after_crop_dies() -> void:
	var plot := _add_plot()
	plot.tilled = true
	plot.watered = false
	plot.crop_id = &"fixture_radish"
	plot.growth_days = 0
	plot.last_processed_day = 1
	plot.call("_advance_to_day", 1_000_000)
	assert_eq(plot.last_processed_day, 1_000_000)
	assert_eq(plot.crop_id, &"")
	assert_eq(plot.growth_days, 0)

func test_unknown_legacy_crop_does_not_block_replanting() -> void:
	var plot := _add_plot()
	plot.load_state_data({
		"tilled": true,
		"watered": false,
		"crop_id": "fixture_removed_crop",
		"growth_days": 999,
		"last_processed_day": WorldClock.day,
	}, false)
	assert_true(plot.tilled)
	assert_eq(plot.crop_id, &"")
	assert_eq(plot.growth_days, 0)
	assert_true(plot.use_item(&"fixture_radish_seeds"))
	assert_eq(plot.crop_id, &"fixture_radish")

func test_plot_blocks_energy_changed_reentrancy_while_planting() -> void:
	var plot := _add_plot()
	assert_true(plot.use_item(&"fixture_hoe"))
	var seeds_before := InventoryState.get_quantity(&"fixture_radish_seeds")
	var energy_before := PlayerState.energy
	var observed := {"entered": false, "inner_result": true}
	var listener := func(_current: int, _maximum: int) -> void:
		if bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_result"] = plot.use_item(&"fixture_radish_seeds")
	PlayerState.energy_changed.connect(listener)
	assert_true(plot.use_item(&"fixture_radish_seeds"))
	if PlayerState.energy_changed.is_connected(listener):
		PlayerState.energy_changed.disconnect(listener)
	assert_true(bool(observed["entered"]))
	assert_false(bool(observed["inner_result"]))
	assert_eq(InventoryState.get_quantity(&"fixture_radish_seeds"), seeds_before - 1)
	assert_eq(PlayerState.energy, energy_before - plot.plant_energy_cost)
	assert_eq(plot.crop_id, &"fixture_radish")

func test_harvest_blocks_item_added_reentrancy() -> void:
	var crop := CropData.find(&"fixture_radish")
	var plot := _add_plot()
	await get_tree().process_frame
	plot.tilled = true
	plot.crop_id = &"fixture_radish"
	plot.growth_days = crop.days_to_mature
	var observed := {"entered": false}
	var listener := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"fixture_radish" or bool(observed["entered"]):
			return
		observed["entered"] = true
		plot.interact(null)
	InventoryState.item_added.connect(listener)
	plot.interact(null)
	if InventoryState.item_added.is_connected(listener):
		InventoryState.item_added.disconnect(listener)
	assert_true(bool(observed["entered"]))
	assert_eq(InventoryState.get_quantity(&"fixture_radish"), crop.harvest_quantity)
	assert_eq(plot.crop_id, &"")

func test_multi_yield_harvest_waits_until_the_full_crop_fits() -> void:
	var crop := CropData.find(&"fixture_twin_radish")
	assert_eq(crop.harvest_quantity, 2)
	var plot := _add_plot()
	await get_tree().process_frame
	plot.crop_id = &"fixture_twin_radish"
	plot.growth_days = crop.days_to_mature
	plot.tilled = true

	InventoryState.clear()
	InventoryState.max_slots = 1
	InventoryState.add_item_by_id(&"fixture_radish", 98)
	plot.interact(null)
	assert_eq(InventoryState.get_quantity(&"fixture_radish"), 98)
	assert_eq(plot.crop_id, &"fixture_twin_radish")
	assert_true(plot.can_harvest())

	assert_true(InventoryState.remove_item(&"fixture_radish", 1))
	plot.interact(null)
	assert_eq(InventoryState.get_quantity(&"fixture_radish"), 99)
	assert_eq(plot.crop_id, &"")

func test_mature_crop_gets_only_one_out_of_season_grace_day() -> void:
	var pepper := CropData.find(&"fixture_pepper")
	WorldClock.set_time(56, 6 * 60) # Summer 28
	var plot := _add_plot()
	await get_tree().process_frame
	plot.load_state_data({
		"tilled": true,
		"watered": true,
		"crop_id": "fixture_pepper",
		"growth_days": pepper.days_to_mature,
		"last_processed_day": 56,
	}, false)

	WorldClock.set_time(57, 6 * 60) # Autumn 1: one harvest grace day.
	assert_eq(plot.crop_id, &"fixture_pepper")
	assert_true(plot.can_harvest())
	WorldClock.set_time(58, 6 * 60) # Autumn 2: unharvested summer crop is gone.
	assert_eq(plot.crop_id, &"")
	assert_false(plot.can_harvest())

func test_summer_crop_grows_only_in_summer_and_regrows_after_harvest() -> void:
	InventoryState.add_item_by_id(&"fixture_pepper_seeds", 2)
	var plot := _add_plot()
	assert_true(plot.use_item(&"fixture_hoe"))
	assert_false(plot.use_item(&"fixture_pepper_seeds"))
	assert_eq(plot.crop_id, &"")

	WorldClock.set_time(29, 6 * 60)
	assert_eq(WorldClock.get_season_name(), "Summer")
	assert_true(plot.use_item(&"fixture_pepper_seeds"))
	if not plot.watered:
		assert_true(plot.use_item(&"fixture_can"))
	for day in range(30, 36):
		WorldClock.set_time(day, 6 * 60)
		if day < 35 and not plot.watered:
			assert_true(plot.use_item(&"fixture_can"))
	assert_true(plot.can_harvest())
	plot.interact(null)
	assert_eq(InventoryState.get_quantity(&"fixture_pepper"), 1)
	assert_eq(plot.crop_id, &"fixture_pepper")
	assert_eq(plot.growth_days, 3)

	if not plot.watered:
		assert_true(plot.use_item(&"fixture_can"))
	for day in range(36, 39):
		WorldClock.set_time(day, 6 * 60)
		if day < 38 and not plot.watered:
			assert_true(plot.use_item(&"fixture_can"))
	assert_true(plot.can_harvest())
	plot.interact(null)
	assert_eq(InventoryState.get_quantity(&"fixture_pepper"), 2)
	assert_eq(plot.crop_id, &"fixture_pepper")

func _add_plot() -> FarmPlot:
	var plot := FARM_PLOT_SCENE.instantiate() as FarmPlot
	plot.persistent_id = &""
	add_child_autofree(plot)
	return plot

# A hoe and a watering can; a spring and autumn radish that matures in four
# days, a radish variety that yields two, and a summer pepper that matures in
# six days and regrows in three.
func _fixture_content() -> Array:
	return [
		_tool(&"fixture_hoe", FarmPlot.TILL_ACTION),
		_tool(&"fixture_can", FarmPlot.WATER_ACTION),
		_seed(&"fixture_radish_seeds", &"fixture_radish"),
		_harvest(&"fixture_radish"),
		_crop(&"fixture_radish", &"fixture_radish", 4, 0, 1, PackedStringArray(["Spring", "Autumn"])),
		_crop(&"fixture_twin_radish", &"fixture_radish", 4, 0, 2, PackedStringArray(["Spring", "Autumn"])),
		_seed(&"fixture_pepper_seeds", &"fixture_pepper"),
		_harvest(&"fixture_pepper"),
		_crop(&"fixture_pepper", &"fixture_pepper", 6, 3, 1, PackedStringArray(["Summer"])),
	]

func _tool(id: StringName, action: StringName) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	item.kind = ItemData.Kind.TOOL
	item.max_stack = 1
	item.tool_action = action
	return item

func _seed(id: StringName, crop_id: StringName) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	item.kind = ItemData.Kind.SEED
	item.crop_id = crop_id
	return item

func _harvest(id: StringName) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	item.kind = ItemData.Kind.CROP
	return item

func _crop(id: StringName, harvest_item_id: StringName, days_to_mature: int, regrow_days: int,
		harvest_quantity: int, seasons: PackedStringArray) -> CropData:
	var crop := CropData.new()
	crop.id = id
	crop.display_name = String(id).capitalize()
	crop.harvest_item_id = harvest_item_id
	crop.days_to_mature = days_to_mature
	crop.regrow_days = regrow_days
	crop.harvest_quantity = harvest_quantity
	crop.allowed_seasons = seasons
	return crop
