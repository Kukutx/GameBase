extends GutTest

var _clock_day: int
var _clock_minute: int
var _world_snapshot: Dictionary
var _inventory_snapshot: Dictionary

func before_each() -> void:
	_clock_day = WorldClock.day
	_clock_minute = WorldClock.minute_of_day
	_world_snapshot = WorldState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	WorldState.clear()
	InventoryState.clear()
	WorldClock.set_time(1, 8 * 60)

func after_each() -> void:
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	WorldClock.set_time(_clock_day, _clock_minute)

func test_generation_is_deterministic_and_location_filtered() -> void:
	var starter := ForageSpawner.new()
	add_child_autofree(starter)
	starter.spawner_id = &"test_starter"
	starter.location_id = &"starter_town"
	starter.spawn_count = 4
	starter.spawn_rect = Rect2(-100, -80, 200, 160)

	var first := starter.generate_plan(1)
	var second := starter.generate_plan(1)
	assert_eq(first, second)
	assert_eq(first.size(), 4)
	for spawn: Dictionary in first:
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

func test_collected_spawn_stays_gone_same_day_and_returns_next_day() -> void:
	var spawner := ForageSpawner.new()
	spawner.spawner_id = &"test_daily_forage"
	spawner.location_id = &"starter_town"
	spawner.spawn_count = 1
	spawner.spawn_rect = Rect2(Vector2.ZERO, Vector2.ONE)
	add_child_autofree(spawner)
	await get_tree().process_frame

	var spawned := spawner.get_spawned_pickups()
	assert_eq(spawned.size(), 1)
	var pickup := spawned[0]
	pickup.get_node("Interactable").interact(null)
	await get_tree().process_frame

	spawner._rebuild(1)
	await get_tree().process_frame
	assert_eq(spawner.get_spawned_pickups().size(), 0)

	WorldClock.set_time(2, 8 * 60)
	await get_tree().process_frame
	assert_eq(spawner.get_spawned_pickups().size(), 1)

func test_pickup_blocks_item_added_reentrancy() -> void:
	var scene := load("res://game/core/items/item_pickup.tscn") as PackedScene
	var pickup := scene.instantiate() as WorldItemPickup
	pickup.item = ContentDB.get_item(&"berry")
	pickup.quantity = 1
	pickup.persistent_id = &"pickup_reentrancy"
	add_child_autofree(pickup)
	await get_tree().process_frame
	var observed := {"entered": false}
	var listener := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"berry" or bool(observed["entered"]):
			return
		observed["entered"] = true
		pickup.get_node("Interactable").interact(null)
	InventoryState.item_added.connect(listener)
	pickup.get_node("Interactable").interact(null)
	if InventoryState.item_added.is_connected(listener):
		InventoryState.item_added.disconnect(listener)
	assert_true(bool(observed["entered"]))
	assert_eq(InventoryState.get_quantity(&"berry"), 1)
	assert_true(WorldState.get_bool(&"pickup:pickup_reentrancy"))
