extends GutTest

const FARM_PLOT_SCENE := preload("res://gamebase/modules/lifesim/farming/farm_plot.tscn")

var _clock_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _vitals_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _world_snapshot: Dictionary
var _quest_snapshot: Dictionary
var _skill_snapshot: Dictionary

func before_each() -> void:
	_clock_snapshot = WorldClock.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_vitals_snapshot = Vitals.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	_quest_snapshot = QuestState.to_save_data()
	_skill_snapshot = Skills.to_save_data()
	WorldClock.set_time(1, 8 * 60)
	InventoryState.clear()
	Vitals.reset_new_game()
	QuestState.load_save_data({})
	Skills.reset_new_game()

func after_each() -> void:
	WorldClock.load_save_data(_clock_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	Vitals.load_save_data(_vitals_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	WorldState.load_save_data(_world_snapshot)
	QuestState.load_save_data(_quest_snapshot)
	Skills.load_save_data(_skill_snapshot)

func test_turnip_seeds_grow_into_one_turnip_after_four_watered_days() -> void:
	InventoryState.add_item_by_id(&"hoe", 1)
	InventoryState.add_item_by_id(&"watering_can", 1)
	InventoryState.add_item_by_id(&"turnip_seeds", 1)
	var plot := _new_plot()
	assert_true(plot.use_item(&"hoe"))
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
	assert_eq(plot.crop_id, &"", "a turnip does not regrow")

func test_tomato_is_summer_only_and_regrows_three_days_after_harvest() -> void:
	InventoryState.add_item_by_id(&"hoe", 1)
	InventoryState.add_item_by_id(&"watering_can", 1)
	InventoryState.add_item_by_id(&"tomato_seeds", 1)
	var plot := _new_plot()
	assert_true(plot.use_item(&"hoe"))
	assert_false(plot.use_item(&"tomato_seeds"), "tomatoes are not planted in spring")

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
	Vitals.set_value(&"energy", 100)
	var copper_hoe := ItemData.find(&"copper_hoe")
	assert_true(controller.call("_use_multi_plot_tool", copper_hoe, target))
	var tilled_count := 0
	for plot: FarmPlot in plots:
		if plot.tilled:
			tilled_count += 1
			plot.watered = false
	assert_eq(tilled_count, 2)
	assert_eq(Vitals.get_value(&"energy"), 98)

	var copper_water := ItemData.find(&"copper_watering_can")
	assert_true(controller.call("_use_multi_plot_tool", copper_water, target))
	var watered_count := 0
	for plot: FarmPlot in plots:
		if plot.watered:
			watered_count += 1
	assert_eq(watered_count, 2)
	assert_eq(Vitals.get_value(&"energy"), 97)

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
	var tool := ItemData.find(&"copper_hoe")
	Vitals.set_value(&"energy", 100)
	var energy_cost := target.get_tool_energy_cost(tool)
	var observed := {"entered": false, "inner_result": true}
	var listener := func(_vital_id: StringName, _current: int, _maximum: int) -> void:
		if bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_result"] = controller.call("_use_multi_plot_tool", tool, target)
	Vitals.changed.connect(listener)
	assert_true(controller.call("_use_multi_plot_tool", tool, target))
	if Vitals.changed.is_connected(listener):
		Vitals.changed.disconnect(listener)
	assert_true(bool(observed["entered"]))
	assert_false(bool(observed["inner_result"]))
	assert_eq(Vitals.get_value(&"energy"), 100 - energy_cost)
	var tilled_count := 0
	for plot: FarmPlot in field.get_all_plots():
		if plot.tilled:
			tilled_count += 1
	assert_eq(tilled_count, 2)

func _new_plot() -> FarmPlot:
	var plot := FARM_PLOT_SCENE.instantiate() as FarmPlot
	plot.persistent_id = &""
	add_child_autofree(plot)
	return plot
