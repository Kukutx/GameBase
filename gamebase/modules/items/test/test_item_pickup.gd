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
	assert_true(WorldState.get_bool(&"pickup:fixture_pickup_reentrancy"))
