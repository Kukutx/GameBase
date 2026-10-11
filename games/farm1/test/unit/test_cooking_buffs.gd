extends GutTest

var _clock_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _buff_snapshot: Dictionary
var _skills_snapshot: Dictionary

func before_each() -> void:
	_clock_snapshot = WorldClock.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_buff_snapshot = BuffState.to_save_data()
	_skills_snapshot = Skills.to_save_data()
	InventoryState.clear()
	PlayerState.reset_new_game()
	BuffState.clear()
	Skills.reset_new_game()
	WorldClock.set_time(1, 8 * 60)

func after_each() -> void:
	WorldClock.load_save_data(_clock_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	Skills.load_save_data(_skills_snapshot)
	BuffState.load_save_data(_buff_snapshot)

func test_cooking_recipes_are_separate_from_workbench_recipes() -> void:
	var stew := CraftingState.get_recipe(&"vegetable_stew")
	var soup := CraftingState.get_recipe(&"fish_soup")
	var sprinkler := CraftingState.get_recipe(&"basic_sprinkler")

	assert_not_null(stew)
	assert_not_null(soup)
	assert_not_null(sprinkler)
	assert_eq(stew.category, RecipeData.Category.COOKING)
	assert_eq(soup.category, RecipeData.Category.COOKING)
	assert_eq(sprinkler.category, RecipeData.Category.CRAFTING)

func test_vegetable_stew_crafts_restores_stats_and_applies_work_buff() -> void:
	InventoryState.add_item_by_id(&"turnip", 1)
	InventoryState.add_item_by_id(&"carrot", 1)
	InventoryState.add_item_by_id(&"potato", 1)
	assert_true(CraftingState.craft(&"vegetable_stew"))
	assert_eq(InventoryState.get_quantity(&"vegetable_stew"), 1)
	assert_eq(InventoryState.get_quantity(&"turnip"), 0)
	assert_eq(InventoryState.get_quantity(&"carrot"), 0)
	assert_eq(InventoryState.get_quantity(&"potato"), 0)

	PlayerState.energy = 40
	PlayerState.health = 50
	var controller := FarmToolController.new()
	add_child_autofree(controller)
	controller._consume_food(ItemData.find(&"vegetable_stew"))

	assert_eq(InventoryState.get_quantity(&"vegetable_stew"), 0)
	assert_eq(PlayerState.energy, 85)
	assert_eq(PlayerState.health, 70)
	assert_true(BuffState.has_buff(&"hearty_worker"))
	assert_almost_eq(BuffState.get_stat_multiplier(&"move_speed"), 1.1, 0.001)
	assert_almost_eq(BuffState.get_stat_multiplier(&"tool_energy"), 0.8, 0.001)

func test_food_use_blocks_item_removed_reentrancy() -> void:
	InventoryState.add_item_by_id(&"vegetable_stew", 2)
	PlayerState.energy = 40
	PlayerState.health = 50
	var controller := FarmToolController.new()
	add_child_autofree(controller)
	var observed := {"entered": false}
	var listener := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"vegetable_stew" or bool(observed["entered"]):
			return
		observed["entered"] = true
		controller._consume_food(ItemData.find(&"vegetable_stew"))
	InventoryState.item_removed.connect(listener)
	controller._consume_food(ItemData.find(&"vegetable_stew"))
	if InventoryState.item_removed.is_connected(listener):
		InventoryState.item_removed.disconnect(listener)
	assert_true(bool(observed["entered"]))
	assert_eq(InventoryState.get_quantity(&"vegetable_stew"), 1)
	assert_eq(PlayerState.energy, 85)
	assert_eq(PlayerState.health, 70)
	assert_true(BuffState.has_buff(&"hearty_worker"))

func test_hearty_worker_reduces_real_hoe_energy_cost() -> void:
	InventoryState.add_item_by_id(&"hoe", 1)
	var plot_scene := load("res://gamebase/modules/lifesim/farming/farm_plot.tscn") as PackedScene
	var plot := plot_scene.instantiate() as FarmPlot
	plot.persistent_id = &""
	add_child_autofree(plot)
	await get_tree().process_frame

	PlayerState.energy = 100
	assert_true(plot.use_item(&"hoe"))
	assert_eq(PlayerState.energy, 96)

	plot.load_state_data({"tilled": false, "watered": false, "crop_id": "", "growth_days": 0, "last_processed_day": 1}, false)
	PlayerState.energy = 100
	assert_true(BuffState.apply_buff(&"hearty_worker"))
	assert_true(plot.use_item(&"hoe"))
	assert_eq(PlayerState.energy, 97)

func test_angler_focus_changes_fishing_timing_and_round_trips_save_data() -> void:
	assert_true(BuffState.apply_buff(&"angler_focus"))
	assert_almost_eq(BuffState.get_stat_multiplier(&"fishing_wait"), 0.7, 0.001)
	assert_almost_eq(BuffState.get_stat_multiplier(&"fishing_window"), 1.35, 0.001)
	var saved := BuffState.to_save_data()
	assert_true(saved.has("angler_focus"))

	BuffState.clear()
	assert_false(BuffState.has_buff(&"angler_focus"))
	BuffState.load_save_data(saved)
	assert_true(BuffState.has_buff(&"angler_focus"))
	assert_eq(BuffState.get_minutes_remaining(&"angler_focus"), 180)

func test_buff_load_clamps_corrupt_far_future_expiry_to_one_game_day() -> void:
	var now := BuffState.get_absolute_minute()
	BuffState.load_save_data({"hearty_worker": now + 999999})
	assert_true(BuffState.has_buff(&"hearty_worker"))
	assert_eq(BuffState.get_minutes_remaining(&"hearty_worker"), GameClock.MINUTES_PER_DAY)

func test_buffs_expire_by_game_time() -> void:
	assert_true(BuffState.apply_buff(&"hearty_worker"))
	assert_eq(BuffState.get_minutes_remaining(&"hearty_worker"), 240)
	WorldClock.set_time(1, 11 * 60 + 59)
	assert_true(BuffState.has_buff(&"hearty_worker"))
	assert_eq(BuffState.get_minutes_remaining(&"hearty_worker"), 1)
	WorldClock.set_time(1, 12 * 60)
	assert_false(BuffState.has_buff(&"hearty_worker"))
