extends GutTest

const FARM_PLOT_SCENE := preload("res://gamebase/modules/lifesim/farming/farm_plot.tscn")

var _world_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _clock_snapshot: Dictionary
var _skills_snapshot: Dictionary
var _player_snapshot: Dictionary

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_clock_snapshot = WorldClock.to_save_data()
	_skills_snapshot = Skills.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	WorldState.clear()
	InventoryState.clear()
	Skills.reset_new_game()
	PlayerState.reset_new_game()
	WorldClock.set_time(1, 8 * 60)

func after_each() -> void:
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	Skills.load_save_data(_skills_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	WorldClock.load_save_data(_clock_snapshot)

func test_sprinkler_is_craftable_placeable_and_refundable() -> void:
	assert_not_null(ContentDB.get_placeable(&"basic_sprinkler"))
	assert_not_null(CraftingState.get_recipe(&"basic_sprinkler"))
	InventoryState.add_item_by_id(&"copper_bar", 1)
	InventoryState.add_item_by_id(&"wood", 2)
	assert_true(CraftingState.craft(&"basic_sprinkler"))
	assert_eq(InventoryState.get_quantity(&"basic_sprinkler"), 1)
	assert_true(PlayerState.hotbar.has(&"basic_sprinkler"))

	var record := BuildingState.place_from_inventory(&"basic_sprinkler", &"starter_town", Vector2(0, 0))
	assert_false(record.is_empty())
	assert_eq(InventoryState.get_quantity(&"basic_sprinkler"), 0)
	assert_eq(BuildingState.get_placements(&"starter_town").size(), 1)
	assert_true(BuildingState.is_point_affected(&"starter_town", &"water", Vector2(40, 0)))
	assert_false(BuildingState.is_point_affected(&"starter_town", &"water", Vector2(100, 0)))

	assert_true(BuildingState.remove_placement(&"starter_town", StringName(String(record["id"])), true))
	assert_eq(BuildingState.get_placements(&"starter_town").size(), 0)
	assert_eq(InventoryState.get_quantity(&"basic_sprinkler"), 1)

func test_placement_from_inventory_blocks_item_removed_reentrancy() -> void:
	InventoryState.add_item_by_id(&"basic_sprinkler", 2)
	var observed := {"entered": false, "inner_record": {"unexpected": true}}
	var listener := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"basic_sprinkler" or bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_record"] = BuildingState.place_from_inventory(&"basic_sprinkler", &"starter_town", Vector2(200, 0))
	InventoryState.item_removed.connect(listener)
	var record := BuildingState.place_from_inventory(&"basic_sprinkler", &"starter_town", Vector2.ZERO)
	if InventoryState.item_removed.is_connected(listener):
		InventoryState.item_removed.disconnect(listener)
	assert_false(record.is_empty())
	assert_true(bool(observed["entered"]))
	assert_true((observed["inner_record"] as Dictionary).is_empty())
	assert_eq(InventoryState.get_quantity(&"basic_sprinkler"), 1)
	assert_eq(BuildingState.get_placements(&"starter_town").size(), 1)

func test_unknown_legacy_placeable_does_not_create_invisible_build_blocker() -> void:
	WorldState.set_value(&"building:placements:starter_town", [{
		"id": "placed_retired_content",
		"placeable_id": "removed_placeable",
		"location_id": "starter_town",
		"x": 0.0,
		"y": 0.0,
	}])
	var raw_before := WorldState.get_value(&"building:placements:starter_town", []) as Array
	assert_eq(raw_before.size(), 1)
	assert_eq(BuildingState.get_placements(&"starter_town").size(), 0)

	# The orphan remains preserved until the player mutates this layout, but it
	# must not block a valid structure at the same coordinates.
	var record := BuildingState.place(&"basic_sprinkler", &"starter_town", Vector2.ZERO)
	assert_false(record.is_empty())
	assert_eq(BuildingState.get_placements(&"starter_town").size(), 1)
	var raw_after := WorldState.get_value(&"building:placements:starter_town", []) as Array
	assert_eq(raw_after.size(), 1)
	assert_eq(String((raw_after[0] as Dictionary).get("placeable_id", "")), "basic_sprinkler")

func test_malformed_known_placeable_records_are_preserved_raw_but_ignored_by_gameplay() -> void:
	var state_key := &"building:placements:starter_town"
	WorldState.set_value(state_key, [
		{"id": "", "placeable_id": "basic_sprinkler", "location_id": "starter_town", "x": 0.0, "y": 0.0},
		{"id": "dup", "placeable_id": "basic_sprinkler", "location_id": "starter_town", "x": 40.0, "y": 0.0},
		{"id": "dup", "placeable_id": "basic_sprinkler", "location_id": "starter_town", "x": 80.0, "y": 0.0},
		{"id": "bad_x", "placeable_id": "basic_sprinkler", "location_id": "starter_town", "x": {"bad": true}, "y": 0.0},
		{"id": "bad_y", "placeable_id": "basic_sprinkler", "location_id": "starter_town", "x": 120.0, "y": [0]},
	])
	var raw_before := WorldState.get_value(state_key, []) as Array
	assert_eq(raw_before.size(), 5)
	var valid := BuildingState.get_placements(&"starter_town")
	assert_eq(valid.size(), 1)
	assert_eq(String(valid[0].get("id", "")), "dup")
	assert_eq(float(valid[0].get("x", 0.0)), 40.0)

	# Invalid records remain in raw WorldState until a real layout mutation, but
	# they must not become blockers or crash numeric placement checks.
	var placed := BuildingState.place(&"basic_sprinkler", &"starter_town", Vector2(200, 0))
	assert_false(placed.is_empty())
	assert_eq(BuildingState.get_placements(&"starter_town").size(), 2)
	var raw_after := WorldState.get_value(state_key, []) as Array
	assert_eq(raw_after.size(), 2)

func test_malformed_building_serial_resets_safely_without_reusing_historical_ids() -> void:
	WorldState.set_value(BuildingPlacementService.SERIAL_KEY, {"bad": true})
	WorldState.set_value(&"building:placements:harbor_town", [{
		"id": "placed_000001",
		"placeable_id": "removed_placeable",
		"location_id": "harbor_town",
		"x": 0.0,
		"y": 0.0,
	}])
	var record := BuildingState.place(&"basic_sprinkler", &"starter_town", Vector2.ZERO)
	assert_false(record.is_empty())
	assert_eq(String(record.get("id", "")), "placed_000002")
	assert_eq(WorldState.get_value(BuildingPlacementService.SERIAL_KEY, 0), 2)
	assert_eq((WorldState.get_value(&"building:placements:harbor_town", []) as Array).size(), 1)

func test_unloaded_farm_catches_up_with_sprinkler_watering() -> void:
	var record := BuildingState.place(&"basic_sprinkler", &"starter_town", Vector2.ZERO)
	assert_false(record.is_empty())

	var plot := FARM_PLOT_SCENE.instantiate() as FarmPlot
	plot.persistent_id = &"test_offline_sprinkler_plot"
	plot.location_id = &"starter_town"
	plot.position = Vector2.ZERO
	add_child(plot)
	plot.load_state_data({
		"tilled": true,
		"watered": true,
		"crop_id": "turnip",
		"growth_days": 0,
		"last_processed_day": 1,
	})

	WorldClock.set_time(2, 6 * 60)
	assert_eq(plot.growth_days, 1)
	assert_true(plot.watered)
	remove_child(plot)
	plot.free()

	# The farm scene is absent while two days pass.
	WorldClock.set_time(4, 6 * 60)

	var restored := FARM_PLOT_SCENE.instantiate() as FarmPlot
	restored.persistent_id = &"test_offline_sprinkler_plot"
	restored.location_id = &"starter_town"
	restored.position = Vector2.ZERO
	add_child(restored)
	assert_eq(restored.last_processed_day, 4)
	assert_eq(restored.growth_days, 3)
	assert_true(restored.watered)
	remove_child(restored)
	restored.free()
