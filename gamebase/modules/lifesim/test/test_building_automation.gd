extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const FARM_PLOT_SCENE := preload("res://gamebase/modules/lifesim/farming/farm_plot.tscn")

var _world_snapshot: Dictionary
var _clock_snapshot: Dictionary

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_clock_snapshot = WorldClock.to_save_data()
	ContentFixture.use(self, _content())
	WorldState.clear()
	WorldClock.set_time(1, 8 * 60)

func after_each() -> void:
	# GUT frees the fixture content after after_each(): restore the saved state
	# against the game's own content.
	ContentRegistry.active = ContentDB
	WorldClock.load_save_data(_clock_snapshot)
	WorldState.load_save_data(_world_snapshot)

func test_unloaded_farm_catches_up_with_sprinkler_watering() -> void:
	var record := BuildingState.place(&"fixture_sprinkler", &"fixture_farm", Vector2.ZERO)
	assert_false(record.is_empty())

	var plot := FARM_PLOT_SCENE.instantiate() as FarmPlot
	plot.persistent_id = &"test_offline_sprinkler_plot"
	plot.location_id = &"fixture_farm"
	plot.position = Vector2.ZERO
	add_child(plot)
	plot.load_state_data({
		"tilled": true,
		"watered": true,
		"crop_id": "fixture_crop",
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
	restored.location_id = &"fixture_farm"
	restored.position = Vector2.ZERO
	add_child(restored)
	assert_eq(restored.last_processed_day, 4)
	assert_eq(restored.growth_days, 3)
	assert_true(restored.watered)
	remove_child(restored)
	restored.free()

func _content() -> Array:
	var farm := WorldLocationData.new()
	farm.id = &"fixture_farm"
	farm.display_name = "Farm"

	var sprinkler := PlaceableData.new()
	sprinkler.id = &"fixture_sprinkler"
	sprinkler.display_name = "Sprinkler"
	sprinkler.item_id = &"fixture_sprinkler"
	sprinkler.scene_path = "res://gamebase/modules/lifesim/farming/basic_sprinkler.tscn"
	# FarmPlot treats a placement with the "water" daily effect as watering.
	sprinkler.daily_effect = &"water"
	sprinkler.effect_radius = 64.0
	var sprinkler_item := _item(&"fixture_sprinkler")
	sprinkler_item.kind = ItemData.Kind.PLACEABLE
	sprinkler_item.placeable_id = &"fixture_sprinkler"

	var crop := CropData.new()
	crop.id = &"fixture_crop"
	crop.display_name = "Crop"
	crop.days_to_mature = 4
	crop.harvest_item_id = &"fixture_harvest"
	var harvest := _item(&"fixture_harvest")
	harvest.kind = ItemData.Kind.CROP
	return [farm, sprinkler, sprinkler_item, crop, harvest]

func _item(id: StringName) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	return item
