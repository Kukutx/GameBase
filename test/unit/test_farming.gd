extends GutTest

var _clock_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _world_snapshot: Dictionary
var _quest_snapshot: Dictionary
var _skill_snapshot: Dictionary
var _inventory_slots: int

func before_each() -> void:
	_clock_snapshot = WorldClock.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	_quest_snapshot = QuestState.to_save_data()
	_skill_snapshot = Skills.to_save_data()
	_inventory_slots = InventoryState.max_slots
	WorldClock.set_time(1, 8 * 60)
	InventoryState.clear()
	PlayerState.reset_new_game()
	QuestState.load_save_data({})
	Skills.reset_new_game()
	InventoryState.add_item_by_id(&"hoe", 1)
	InventoryState.add_item_by_id(&"watering_can", 1)
	InventoryState.add_item_by_id(&"turnip_seeds", 5)

func after_each() -> void:
	WorldClock.load_save_data(_clock_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	WorldState.load_save_data(_world_snapshot)
	QuestState.load_save_data(_quest_snapshot)
	Skills.load_save_data(_skill_snapshot)
	InventoryState.max_slots = _inventory_slots

func test_full_turnip_growth_cycle() -> void:
	var plot := load("res://gamebase/modules/lifesim/farming/farm_plot.tscn").instantiate() as FarmPlot
	plot.persistent_id = &""
	add_child_autofree(plot)

	assert_true(plot.use_item(&"hoe"))
	assert_true(plot.tilled)
	assert_true(plot.use_item(&"turnip_seeds"))
	assert_eq(plot.crop_id, &"turnip")
	if not plot.watered:
		assert_true(plot.use_item(&"watering_can"))

	for day in range(2, 6):
		WorldClock.set_time(day, 6 * 60)
		if day < 5 and not plot.watered:
			assert_true(plot.use_item(&"watering_can"))

	assert_eq(plot.growth_days, 4)
	assert_true(plot.can_harvest())
	plot.interact(null)
	assert_eq(InventoryState.get_quantity(&"turnip"), 1)
	assert_eq(plot.crop_id, &"")

func test_loaded_farm_state_clamps_future_day_and_excess_growth() -> void:
	WorldClock.set_time(10, 8 * 60)
	var crop := ContentDB.get_crop(&"turnip")
	assert_not_null(crop)
	if crop == null:
		return
	var plot := load("res://gamebase/modules/lifesim/farming/farm_plot.tscn").instantiate() as FarmPlot
	plot.persistent_id = &""
	add_child_autofree(plot)
	plot.load_state_data({
		"tilled": true,
		"watered": true,
		"crop_id": "turnip",
		"growth_days": 999999,
		"last_processed_day": 999999,
	}, false)
	assert_eq(plot.growth_days, crop.days_to_mature)
	assert_eq(plot.last_processed_day, 10)
	assert_true(plot.can_harvest())

func test_empty_plot_catchup_handles_extreme_day_jump_without_per_day_iteration() -> void:
	var plot := load("res://gamebase/modules/lifesim/farming/farm_plot.tscn").instantiate() as FarmPlot
	plot.persistent_id = &""
	add_child_autofree(plot)
	plot.tilled = true
	plot.watered = false
	plot.crop_id = &""
	plot.last_processed_day = 1
	plot.call("_advance_to_day", 1_000_000)
	assert_eq(plot.last_processed_day, 1_000_000)
	assert_eq(plot.crop_id, &"")
	assert_eq(plot.watered, plot.tilled and bool(WeatherState.is_raining(1_000_000)))

func test_seasonal_crop_catchup_stops_simulating_after_crop_dies() -> void:
	var plot := load("res://gamebase/modules/lifesim/farming/farm_plot.tscn").instantiate() as FarmPlot
	plot.persistent_id = &""
	add_child_autofree(plot)
	plot.tilled = true
	plot.watered = false
	plot.crop_id = &"turnip"
	plot.growth_days = 0
	plot.last_processed_day = 1
	plot.call("_advance_to_day", 1_000_000)
	assert_eq(plot.last_processed_day, 1_000_000)
	assert_eq(plot.crop_id, &"")
	assert_eq(plot.growth_days, 0)

func test_unknown_legacy_crop_does_not_block_replanting() -> void:
	var plot := load("res://gamebase/modules/lifesim/farming/farm_plot.tscn").instantiate() as FarmPlot
	plot.persistent_id = &""
	add_child_autofree(plot)
	plot.load_state_data({
		"tilled": true,
		"watered": false,
		"crop_id": "removed_crop",
		"growth_days": 999,
		"last_processed_day": WorldClock.day,
	}, false)
	assert_true(plot.tilled)
	assert_eq(plot.crop_id, &"")
	assert_eq(plot.growth_days, 0)
	assert_true(plot.use_item(&"turnip_seeds"))
	assert_eq(plot.crop_id, &"turnip")

func test_plot_blocks_energy_changed_reentrancy_while_planting() -> void:
	var plot := load("res://gamebase/modules/lifesim/farming/farm_plot.tscn").instantiate() as FarmPlot
	plot.persistent_id = &""
	add_child_autofree(plot)
	assert_true(plot.use_item(&"hoe"))
	var seeds_before := InventoryState.get_quantity(&"turnip_seeds")
	var energy_before := PlayerState.energy
	var observed := {"entered": false, "inner_result": true}
	var listener := func(_current: int, _maximum: int) -> void:
		if bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_result"] = plot.use_item(&"turnip_seeds")
	PlayerState.energy_changed.connect(listener)
	assert_true(plot.use_item(&"turnip_seeds"))
	if PlayerState.energy_changed.is_connected(listener):
		PlayerState.energy_changed.disconnect(listener)
	assert_true(bool(observed["entered"]))
	assert_false(bool(observed["inner_result"]))
	assert_eq(InventoryState.get_quantity(&"turnip_seeds"), seeds_before - 1)
	assert_eq(PlayerState.energy, energy_before - plot.plant_energy_cost)
	assert_eq(plot.crop_id, &"turnip")

func test_harvest_blocks_item_added_reentrancy() -> void:
	var crop := ContentDB.get_crop(&"turnip")
	var plot := load("res://gamebase/modules/lifesim/farming/farm_plot.tscn").instantiate() as FarmPlot
	plot.persistent_id = &""
	add_child_autofree(plot)
	await get_tree().process_frame
	plot.tilled = true
	plot.crop_id = &"turnip"
	plot.growth_days = crop.days_to_mature
	InventoryState.remove_item(&"turnip", InventoryState.get_quantity(&"turnip"))
	var observed := {"entered": false}
	var listener := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"turnip" or bool(observed["entered"]):
			return
		observed["entered"] = true
		plot.interact(null)
	InventoryState.item_added.connect(listener)
	plot.interact(null)
	if InventoryState.item_added.is_connected(listener):
		InventoryState.item_added.disconnect(listener)
	assert_true(bool(observed["entered"]))
	assert_eq(InventoryState.get_quantity(&"turnip"), crop.harvest_quantity)
	assert_eq(plot.crop_id, &"")

func test_multi_yield_harvest_waits_until_the_full_crop_fits() -> void:
	var crop := ContentDB.get_crop(&"turnip")
	assert_not_null(crop)
	if crop == null:
		return
	var original_quantity := crop.harvest_quantity
	crop.harvest_quantity = 2
	var plot := load("res://gamebase/modules/lifesim/farming/farm_plot.tscn").instantiate() as FarmPlot
	plot.persistent_id = &""
	add_child_autofree(plot)
	await get_tree().process_frame
	plot.crop_id = &"turnip"
	plot.growth_days = crop.days_to_mature
	plot.tilled = true

	InventoryState.clear()
	InventoryState.max_slots = 1
	InventoryState.add_item_by_id(&"turnip", 98)
	plot.interact(null)
	assert_eq(InventoryState.get_quantity(&"turnip"), 98)
	assert_eq(plot.crop_id, &"turnip")
	assert_true(plot.can_harvest())

	assert_true(InventoryState.remove_item(&"turnip", 1))
	plot.interact(null)
	assert_eq(InventoryState.get_quantity(&"turnip"), 99)
	assert_eq(plot.crop_id, &"")
	crop.harvest_quantity = original_quantity

func test_copper_farm_tools_affect_two_adjacent_plots_for_one_energy_charge() -> void:
	for index in range(1, 4):
		WorldState.erase(StringName("farm:unit_range_%02d" % index))
	InventoryState.add_item_by_id(&"copper_hoe", 1)
	InventoryState.add_item_by_id(&"copper_watering_can", 1)
	var field := FarmField.new()
	field.field_id = &"unit_range"
	field.location_id = &"starter_town"
	field.columns = 3
	field.rows = 1
	field.cell_spacing = Vector2(45, 32)
	add_child_autofree(field)
	await get_tree().process_frame
	var plots := field.get_all_plots()
	assert_eq(plots.size(), 3)
	var controller := FarmToolController.new()
	add_child_autofree(controller)
	var target := field.get_plot(Vector2i(0, 0))
	PlayerState.energy = 100
	var copper_hoe := ContentDB.get_item(&"copper_hoe")
	assert_true(controller.call("_use_multi_plot_tool", copper_hoe, target))
	var tilled_count := 0
	for plot: FarmPlot in plots:
		if plot.tilled:
			tilled_count += 1
			plot.watered = false
	assert_eq(tilled_count, 2)
	assert_eq(PlayerState.energy, 98)

	var copper_water := ContentDB.get_item(&"copper_watering_can")
	assert_true(controller.call("_use_multi_plot_tool", copper_water, target))
	var watered_count := 0
	for plot: FarmPlot in plots:
		if plot.watered:
			watered_count += 1
	assert_eq(watered_count, 2)
	assert_eq(PlayerState.energy, 97)

func test_multi_plot_tool_blocks_energy_changed_reentrancy() -> void:
	for index in range(1, 4):
		WorldState.erase(StringName("farm:unit_reentrant_%02d" % index))
	InventoryState.add_item_by_id(&"copper_hoe", 1)
	var field := FarmField.new()
	field.field_id = &"unit_reentrant"
	field.location_id = &"starter_town"
	field.columns = 3
	field.rows = 1
	field.cell_spacing = Vector2(45, 32)
	add_child_autofree(field)
	await get_tree().process_frame
	var controller := FarmToolController.new()
	add_child_autofree(controller)
	var target := field.get_plot(Vector2i(0, 0))
	var tool := ContentDB.get_item(&"copper_hoe")
	PlayerState.energy = 100
	var energy_cost := target.get_tool_energy_cost(tool)
	var observed := {"entered": false, "inner_result": true}
	var listener := func(_current: int, _maximum: int) -> void:
		if bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_result"] = controller.call("_use_multi_plot_tool", tool, target)
	PlayerState.energy_changed.connect(listener)
	assert_true(controller.call("_use_multi_plot_tool", tool, target))
	if PlayerState.energy_changed.is_connected(listener):
		PlayerState.energy_changed.disconnect(listener)
	assert_true(bool(observed["entered"]))
	assert_false(bool(observed["inner_result"]))
	assert_eq(PlayerState.energy, 100 - energy_cost)
	var tilled_count := 0
	for plot: FarmPlot in field.get_all_plots():
		if plot.tilled:
			tilled_count += 1
	assert_eq(tilled_count, 2)

func test_mature_crop_gets_only_one_out_of_season_grace_day() -> void:
	var tomato := ContentDB.get_crop(&"tomato")
	assert_not_null(tomato)
	if tomato == null:
		return
	WorldClock.set_time(56, 6 * 60) # Summer 28
	var plot := load("res://gamebase/modules/lifesim/farming/farm_plot.tscn").instantiate() as FarmPlot
	plot.persistent_id = &""
	add_child_autofree(plot)
	await get_tree().process_frame
	plot.load_state_data({
		"tilled": true,
		"watered": true,
		"crop_id": "tomato",
		"growth_days": tomato.days_to_mature,
		"last_processed_day": 56,
	}, false)

	WorldClock.set_time(57, 6 * 60) # Autumn 1: one harvest grace day.
	assert_eq(plot.crop_id, &"tomato")
	assert_true(plot.can_harvest())
	WorldClock.set_time(58, 6 * 60) # Autumn 2: unharvested summer crop is gone.
	assert_eq(plot.crop_id, &"")
	assert_false(plot.can_harvest())

func test_tomato_is_summer_only_and_regrows_after_harvest() -> void:
	InventoryState.add_item_by_id(&"tomato_seeds", 2)
	var plot := load("res://gamebase/modules/lifesim/farming/farm_plot.tscn").instantiate() as FarmPlot
	plot.persistent_id = &""
	add_child_autofree(plot)
	assert_true(plot.use_item(&"hoe"))
	assert_false(plot.use_item(&"tomato_seeds"))
	assert_eq(plot.crop_id, &"")

	WorldClock.set_time(29, 6 * 60)
	assert_eq(WorldClock.get_season_name(), "Summer")
	assert_true(plot.use_item(&"tomato_seeds"))
	if not plot.watered:
		assert_true(plot.use_item(&"watering_can"))
	for day in range(30, 36):
		WorldClock.set_time(day, 6 * 60)
		if day < 35 and not plot.watered:
			assert_true(plot.use_item(&"watering_can"))
	assert_true(plot.can_harvest())
	plot.interact(null)
	assert_eq(InventoryState.get_quantity(&"tomato"), 1)
	assert_eq(plot.crop_id, &"tomato")
	assert_eq(plot.growth_days, 3)

	if not plot.watered:
		assert_true(plot.use_item(&"watering_can"))
	for day in range(36, 39):
		WorldClock.set_time(day, 6 * 60)
		if day < 38 and not plot.watered:
			assert_true(plot.use_item(&"watering_can"))
	assert_true(plot.can_harvest())
	plot.interact(null)
	assert_eq(InventoryState.get_quantity(&"tomato"), 2)
	assert_eq(plot.crop_id, &"tomato")
