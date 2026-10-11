extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
## Any placeable scene will do: a placement only needs the scene to exist.
const BEACON_SCENE := "res://gamebase/modules/items/storage/storage_chest.tscn"

var _world_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _hotbar_snapshot: Dictionary

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	ContentFixture.use(self, _content())
	WorldState.clear()
	InventoryState.clear()
	for index in Hotbar.slots.size():
		Hotbar.set_slot_item(index, &"")

func after_each() -> void:
	# GUT frees the fixture content after after_each(): restore the saved state
	# against the game's own content.
	ContentRegistry.active = ContentDB
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)

func test_placeable_is_craftable_placeable_and_refundable() -> void:
	InventoryState.add_item_by_id(&"fixture_ingot", 1)
	InventoryState.add_item_by_id(&"fixture_plank", 2)
	assert_true(CraftingState.craft(&"fixture_beacon"))
	assert_eq(InventoryState.get_quantity(&"fixture_beacon"), 1)
	assert_true(Hotbar.slots.has(&"fixture_beacon"), "a crafted placeable lands on the hotbar")

	var record := BuildingState.place_from_inventory(&"fixture_beacon", &"fixture_farm", Vector2(0, 0))
	assert_false(record.is_empty())
	assert_eq(InventoryState.get_quantity(&"fixture_beacon"), 0)
	assert_eq(BuildingState.get_placements(&"fixture_farm").size(), 1)
	assert_true(BuildingState.is_point_affected(&"fixture_farm", &"fixture_glow", Vector2(40, 0)))
	assert_false(BuildingState.is_point_affected(&"fixture_farm", &"fixture_glow", Vector2(100, 0)))
	assert_false(BuildingState.is_point_affected(&"fixture_farm", &"fixture_other_effect", Vector2(40, 0)))

	assert_true(BuildingState.remove_placement(&"fixture_farm", StringName(String(record["id"])), true))
	assert_eq(BuildingState.get_placements(&"fixture_farm").size(), 0)
	assert_eq(InventoryState.get_quantity(&"fixture_beacon"), 1)

func test_placement_from_inventory_blocks_item_removed_reentrancy() -> void:
	InventoryState.add_item_by_id(&"fixture_beacon", 2)
	var observed := {"entered": false, "inner_record": {"unexpected": true}}
	var listener := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"fixture_beacon" or bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_record"] = BuildingState.place_from_inventory(&"fixture_beacon", &"fixture_farm", Vector2(200, 0))
	InventoryState.item_removed.connect(listener)
	var record := BuildingState.place_from_inventory(&"fixture_beacon", &"fixture_farm", Vector2.ZERO)
	if InventoryState.item_removed.is_connected(listener):
		InventoryState.item_removed.disconnect(listener)
	assert_false(record.is_empty())
	assert_true(bool(observed["entered"]))
	assert_true((observed["inner_record"] as Dictionary).is_empty())
	assert_eq(InventoryState.get_quantity(&"fixture_beacon"), 1)
	assert_eq(BuildingState.get_placements(&"fixture_farm").size(), 1)

func test_unknown_legacy_placeable_does_not_create_invisible_build_blocker() -> void:
	WorldState.set_value(&"building:placements:fixture_farm", [{
		"id": "placed_retired_content",
		"placeable_id": "removed_placeable",
		"location_id": "fixture_farm",
		"x": 0.0,
		"y": 0.0,
	}])
	var raw_before := WorldState.get_value(&"building:placements:fixture_farm", []) as Array
	assert_eq(raw_before.size(), 1)
	assert_eq(BuildingState.get_placements(&"fixture_farm").size(), 0)

	# The orphan remains preserved until the player mutates this layout, but it
	# must not block a valid structure at the same coordinates.
	var record := BuildingState.place(&"fixture_beacon", &"fixture_farm", Vector2.ZERO)
	assert_false(record.is_empty())
	assert_eq(BuildingState.get_placements(&"fixture_farm").size(), 1)
	var raw_after := WorldState.get_value(&"building:placements:fixture_farm", []) as Array
	assert_eq(raw_after.size(), 1)
	assert_eq(String((raw_after[0] as Dictionary).get("placeable_id", "")), "fixture_beacon")

func test_malformed_known_placeable_records_are_preserved_raw_but_ignored_by_gameplay() -> void:
	var state_key := &"building:placements:fixture_farm"
	WorldState.set_value(state_key, [
		{"id": "", "placeable_id": "fixture_beacon", "location_id": "fixture_farm", "x": 0.0, "y": 0.0},
		{"id": "dup", "placeable_id": "fixture_beacon", "location_id": "fixture_farm", "x": 40.0, "y": 0.0},
		{"id": "dup", "placeable_id": "fixture_beacon", "location_id": "fixture_farm", "x": 80.0, "y": 0.0},
		{"id": "bad_x", "placeable_id": "fixture_beacon", "location_id": "fixture_farm", "x": {"bad": true}, "y": 0.0},
		{"id": "bad_y", "placeable_id": "fixture_beacon", "location_id": "fixture_farm", "x": 120.0, "y": [0]},
	])
	var raw_before := WorldState.get_value(state_key, []) as Array
	assert_eq(raw_before.size(), 5)
	var valid := BuildingState.get_placements(&"fixture_farm")
	assert_eq(valid.size(), 1)
	assert_eq(String(valid[0].get("id", "")), "dup")
	assert_eq(float(valid[0].get("x", 0.0)), 40.0)

	# Invalid records remain in raw WorldState until a real layout mutation, but
	# they must not become blockers or crash numeric placement checks.
	var placed := BuildingState.place(&"fixture_beacon", &"fixture_farm", Vector2(200, 0))
	assert_false(placed.is_empty())
	assert_eq(BuildingState.get_placements(&"fixture_farm").size(), 2)
	var raw_after := WorldState.get_value(state_key, []) as Array
	assert_eq(raw_after.size(), 2)

func test_malformed_building_serial_resets_safely_without_reusing_historical_ids() -> void:
	WorldState.set_value(BuildingPlacementService.SERIAL_KEY, {"bad": true})
	WorldState.set_value(&"building:placements:fixture_cellar", [{
		"id": "placed_000001",
		"placeable_id": "removed_placeable",
		"location_id": "fixture_cellar",
		"x": 0.0,
		"y": 0.0,
	}])
	var record := BuildingState.place(&"fixture_beacon", &"fixture_farm", Vector2.ZERO)
	assert_false(record.is_empty())
	assert_eq(String(record.get("id", "")), "placed_000002")
	assert_eq(WorldState.get_value(BuildingPlacementService.SERIAL_KEY, 0), 2)
	assert_eq((WorldState.get_value(&"building:placements:fixture_cellar", []) as Array).size(), 1)

func _content() -> Array:
	var farm := WorldLocationData.new()
	farm.id = &"fixture_farm"
	farm.display_name = "Farm"

	var beacon := PlaceableData.new()
	beacon.id = &"fixture_beacon"
	beacon.display_name = "Beacon"
	beacon.item_id = &"fixture_beacon"
	beacon.scene_path = BEACON_SCENE
	beacon.snap_size = 16
	beacon.minimum_spacing = 24.0
	beacon.daily_effect = &"fixture_glow"
	beacon.effect_radius = 64.0
	beacon.allowed_location_ids.assign([&"fixture_farm"])
	var beacon_item := _item(&"fixture_beacon")
	beacon_item.kind = ItemData.Kind.PLACEABLE
	beacon_item.placeable_id = &"fixture_beacon"

	var recipe := RecipeData.new()
	recipe.id = &"fixture_beacon"
	recipe.display_name = "Beacon"
	recipe.ingredients = {"fixture_ingot": 1, "fixture_plank": 2}
	recipe.output_item_id = &"fixture_beacon"
	return [farm, beacon, beacon_item, _item(&"fixture_ingot"), _item(&"fixture_plank"), recipe]

func _item(id: StringName) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	return item
