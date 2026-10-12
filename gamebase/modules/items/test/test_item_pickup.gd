extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

var _world_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _hotbar_snapshot: Dictionary

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	var berry := ItemData.new()
	berry.id = &"fixture_berry"
	berry.display_name = "Berry"
	ContentFixture.use(self, [berry])
	WorldState.clear()
	InventoryState.clear()

func after_each() -> void:
	# GUT frees the fixture content only after this method: restore the
	# services with the game's content, which their snapshots name.
	ContentRegistry.active = ContentDB
	WorldState.load_save_data(_world_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)

func test_pickup_blocks_item_added_reentrancy() -> void:
	var scene := load("res://gamebase/modules/items/items/item_pickup.tscn") as PackedScene
	var pickup := scene.instantiate() as WorldItemPickup
	pickup.item = ItemData.find(&"fixture_berry")
	pickup.quantity = 1
	pickup.persistent_id = &"fixture_pickup_reentrancy"
	add_child_autofree(pickup)
	await get_tree().process_frame
	var observed := {"entered": false}
	var listener := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"fixture_berry" or bool(observed["entered"]):
			return
		observed["entered"] = true
		pickup.get_node("Interactable").interact(null)
	InventoryState.item_added.connect(listener)
	pickup.get_node("Interactable").interact(null)
	if InventoryState.item_added.is_connected(listener):
		InventoryState.item_added.disconnect(listener)
	assert_true(bool(observed["entered"]))
	assert_eq(InventoryState.get_quantity(&"fixture_berry"), 1)
	assert_eq(WorldState.get_value(&"pickup:fixture_pickup_reentrancy"), 0, "taken whole")

func test_a_pickup_taken_in_part_keeps_only_the_rest() -> void:
	var berry := ItemData.find(&"fixture_berry")
	berry.max_stack = 2
	var max_slots := InventoryState.max_slots
	InventoryState.max_slots = 1
	var first := _pickup(5)
	first.get_node("Interactable").interact(null)
	InventoryState.max_slots = max_slots
	assert_eq(InventoryState.get_quantity(&"fixture_berry"), 2, "the bag held two")
	assert_eq(WorldState.get_value(&"pickup:fixture_bush"), 3)
	# Leaving and coming back builds the pickup again from its scene.
	var again := _pickup(5)
	assert_eq(again.quantity, 3, "the rest is still there, no more")
	again.get_node("Interactable").interact(null)
	assert_true(again.is_queued_for_deletion())
	var gone := _pickup(5)
	assert_true(gone.is_queued_for_deletion(), "a pickup taken whole stays gone")

func _pickup(quantity: int) -> WorldItemPickup:
	var pickup := (load("res://gamebase/modules/items/items/item_pickup.tscn") as PackedScene).instantiate() as WorldItemPickup
	pickup.item = ItemData.find(&"fixture_berry")
	pickup.quantity = quantity
	pickup.persistent_id = &"fixture_bush"
	add_child_autofree(pickup)
	return pickup
