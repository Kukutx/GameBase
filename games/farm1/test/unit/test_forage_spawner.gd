extends GutTest

## What Farm1's towns grow for foraging. How spawners plan, place and respawn
## forage is tested on fixture content with the lifesim module.

var _clock_snapshot: Dictionary
var _world_snapshot: Dictionary

func before_each() -> void:
	_clock_snapshot = WorldClock.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	WorldState.clear()
	WorldClock.set_time(1, 8 * 60)

func after_each() -> void:
	WorldState.load_save_data(_world_snapshot)
	WorldClock.load_save_data(_clock_snapshot)

func test_starter_town_forages_berries_and_wood_and_the_harbor_only_seaweed() -> void:
	var starter := ForageSpawner.new()
	add_child_autofree(starter)
	starter.spawner_id = &"test_starter"
	starter.location_id = &"starter_town"
	starter.spawn_count = 4
	starter.spawn_rect = Rect2(-100, -80, 200, 160)
	var starter_plan := starter.generate_plan(1)
	assert_eq(starter_plan.size(), 4)
	for spawn: Dictionary in starter_plan:
		assert_true(["berry", "wood"].has(String(spawn["item_id"])))

	var harbor := ForageSpawner.new()
	add_child_autofree(harbor)
	harbor.spawner_id = &"test_harbor"
	harbor.location_id = &"harbor_town"
	harbor.spawn_count = 3
	var harbor_plan := harbor.generate_plan(1)
	assert_eq(harbor_plan.size(), 3)
	for spawn: Dictionary in harbor_plan:
		assert_eq(String(spawn["item_id"]), "seaweed")
