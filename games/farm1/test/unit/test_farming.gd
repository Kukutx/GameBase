extends GutTest

var _clock_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _world_snapshot: Dictionary
var _quest_snapshot: Dictionary
var _skill_snapshot: Dictionary

func before_each() -> void:
	_clock_snapshot = WorldClock.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	_quest_snapshot = QuestState.to_save_data()
	_skill_snapshot = Skills.to_save_data()
	WorldClock.set_time(1, 8 * 60)
	InventoryState.clear()
	PlayerState.reset_new_game()
	QuestState.load_save_data({})
	Skills.reset_new_game()

func after_each() -> void:
	WorldClock.load_save_data(_clock_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	WorldState.load_save_data(_world_snapshot)
	QuestState.load_save_data(_quest_snapshot)
	Skills.load_save_data(_skill_snapshot)

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
	var copper_hoe := ItemData.find(&"copper_hoe")
	assert_true(controller.call("_use_multi_plot_tool", copper_hoe, target))
	var tilled_count := 0
	for plot: FarmPlot in plots:
		if plot.tilled:
			tilled_count += 1
			plot.watered = false
	assert_eq(tilled_count, 2)
	assert_eq(PlayerState.energy, 98)

	var copper_water := ItemData.find(&"copper_watering_can")
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
	var tool := ItemData.find(&"copper_hoe")
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
