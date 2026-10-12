extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

var _clock_snapshot: Dictionary
var _world_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _skill_snapshot: Dictionary

func before_each() -> void:
	_clock_snapshot = WorldClock.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_skill_snapshot = Skills.to_save_data()
	ContentFixture.use(self, _fixture_content())
	WorldState.clear()
	InventoryState.clear()
	WorldClock.set_time(1, 8 * 60)

func after_each() -> void:
	# GUT frees the fixture content only after this method: restore the
	# services with the game's content, which their snapshots name.
	ContentRegistry.active = ContentDB
	WorldClock.load_save_data(_clock_snapshot)
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	Skills.load_save_data(_skill_snapshot)

func test_generation_is_deterministic_and_location_filtered() -> void:
	var meadow := ForageSpawner.new()
	add_child_autofree(meadow)
	meadow.spawner_id = &"fixture_meadow_spawner"
	meadow.location_id = &"fixture_meadow"
	meadow.spawn_count = 4
	meadow.spawn_rect = Rect2(-100, -80, 200, 160)

	var first := meadow.generate_plan(1)
	var second := meadow.generate_plan(1)
	assert_eq(first, second)
	assert_eq(first.size(), 4)
	for spawn: Dictionary in first:
		assert_true(["fixture_berry", "fixture_twig"].has(String(spawn["item_id"])))

	var shore := ForageSpawner.new()
	add_child_autofree(shore)
	shore.spawner_id = &"fixture_shore_spawner"
	shore.location_id = &"fixture_shore"
	shore.spawn_count = 3
	var shore_plan := shore.generate_plan(1)
	assert_eq(shore_plan.size(), 3)
	for spawn: Dictionary in shore_plan:
		assert_eq(String(spawn["item_id"]), "fixture_kelp")

func test_collected_spawn_stays_gone_same_day_and_returns_next_day() -> void:
	var spawner := ForageSpawner.new()
	spawner.spawner_id = &"fixture_daily_forage"
	spawner.location_id = &"fixture_meadow"
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

func test_a_spawn_taken_in_part_keeps_only_the_rest_that_day() -> void:
	for entry: ForageEntryData in ForageEntryData.find_all():
		entry.min_quantity = 3
		entry.max_quantity = 3
	var spawner := ForageSpawner.new()
	spawner.spawner_id = &"fixture_partial_forage"
	spawner.location_id = &"fixture_meadow"
	spawner.spawn_count = 1
	spawner.spawn_rect = Rect2(Vector2.ZERO, Vector2.ONE)
	add_child_autofree(spawner)
	await get_tree().process_frame
	var max_slots := InventoryState.max_slots
	InventoryState.max_slots = 1
	var pickup := spawner.get_spawned_pickups()[0]
	(pickup.item as ItemData).max_stack = 1
	pickup.get_node("Interactable").interact(null)
	InventoryState.max_slots = max_slots
	assert_eq(pickup.quantity, 2, "the bag held one")

	# Leaving and coming back the same day builds the spawns again.
	spawner._rebuild(1)
	await get_tree().process_frame
	var again := spawner.get_spawned_pickups()
	assert_eq(again.size(), 1)
	assert_eq(again[0].quantity, 2, "the rest is still there, no more")

# A meadow where berries and twigs grow, and a shore where kelp washes up.
func _fixture_content() -> Array:
	return [
		_item(&"fixture_berry"),
		_item(&"fixture_twig"),
		_item(&"fixture_kelp"),
		_forage(&"fixture_meadow_berry", &"fixture_berry", &"fixture_meadow"),
		_forage(&"fixture_meadow_twig", &"fixture_twig", &"fixture_meadow"),
		_forage(&"fixture_shore_kelp", &"fixture_kelp", &"fixture_shore"),
	]

func _item(id: StringName) -> ItemData:
	var item := ItemData.new()
	item.id = id
	item.display_name = String(id).capitalize()
	return item

func _forage(id: StringName, item_id: StringName, location_id: StringName) -> ForageEntryData:
	var entry := ForageEntryData.new()
	entry.id = id
	entry.item_id = item_id
	entry.locations.assign([location_id])
	return entry
