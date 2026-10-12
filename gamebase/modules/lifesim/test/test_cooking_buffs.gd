extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
## The vital the life-sim work spends here.
const ENERGY := &"fixture_energy"
const FARM_PLOT_SCENE := preload("res://gamebase/modules/lifesim/farming/farm_plot.tscn")

var _clock_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _vitals_snapshot: Dictionary
var _buff_snapshot: Dictionary

func before_each() -> void:
	_clock_snapshot = WorldClock.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_vitals_snapshot = Vitals.to_save_data()
	_buff_snapshot = BuffState.to_save_data()
	var hoe := ItemData.new()
	hoe.id = &"fixture_hoe"
	hoe.display_name = "Hoe"
	hoe.kind = ItemData.Kind.TOOL
	hoe.max_stack = 1
	hoe.tool_action = FarmPlot.TILL_ACTION
	hoe.tool_power = 1
	var buff := FoodBuffData.new()
	buff.id = &"fixture_vigor"
	buff.display_name = "Vigor"
	buff.duration_minutes = 240
	buff.multipliers[&"tool_energy"] = 0.8
	ContentFixture.use(self, [hoe, buff, ContentFixture.vital(ENERGY)])
	_use_energy()
	InventoryState.clear()
	Vitals.reset_new_game()
	BuffState.clear()
	WorldClock.set_time(1, 8 * 60)

func after_each() -> void:
	# GUT frees the fixture content after after_each(): restore the saved state
	# against the game's own content.
	ContentRegistry.active = ContentDB
	WorldClock.load_save_data(_clock_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	Vitals.load_save_data(_vitals_snapshot)
	BuffState.load_save_data(_buff_snapshot)

func test_food_buff_on_tool_energy_lowers_what_tilling_a_plot_costs() -> void:
	InventoryState.add_item_by_id(&"fixture_hoe", 1)
	var plot := FARM_PLOT_SCENE.instantiate() as FarmPlot
	plot.persistent_id = &""
	plot.hoe_energy_cost = 4
	add_child_autofree(plot)
	await get_tree().process_frame

	Vitals.set_value(ENERGY, 100)
	assert_true(plot.use_item(&"fixture_hoe"))
	assert_eq(Vitals.get_value(ENERGY), 96)

	plot.load_state_data({"tilled": false, "watered": false, "crop_id": "", "growth_days": 0, "last_processed_day": 1}, false)
	Vitals.set_value(ENERGY, 100)
	assert_true(BuffState.apply_buff(&"fixture_vigor"))
	assert_true(plot.use_item(&"fixture_hoe"))
	assert_eq(Vitals.get_value(ENERGY), 97, "4 energy x 0.8, rounded down")

# Makes `ENERGY` the vital the life-sim work spends.
func _use_energy() -> void:
	var settings := LifesimSettings.new()
	settings.energy_vital_id = ENERGY
	ContentFixture.use_settings(self, [settings])
