extends GutTest

## `OverflowDrop`: what the bag cannot hold waits on the ground by its node,
## one pile that follows what the player takes.

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")

var _world_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _inventory_slots: int
var _scene_before: Node
var _stone: ItemData
# Stands in for the place the player is in.
var _place: Node2D

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_inventory_slots = InventoryState.max_slots
	_stone = ItemData.new()
	_stone.id = &"fixture_stone"
	_stone.display_name = "Stone"
	_stone.max_stack = 5
	ContentFixture.use(self, [_stone])
	WorldState.clear()
	InventoryState.clear()
	InventoryState.max_slots = 1
	# A scene is a child of the root.
	_place = Node2D.new()
	get_tree().root.add_child(_place)
	autofree(_place)
	_scene_before = get_tree().current_scene
	get_tree().current_scene = _place

func after_each() -> void:
	get_tree().current_scene = _scene_before
	# GUT frees the fixture content only after this method: restore the
	# services with the game's content, which their snapshots name.
	ContentRegistry.active = ContentDB
	InventoryState.max_slots = _inventory_slots
	InventoryState.load_save_data(_inventory_snapshot)
	WorldState.load_save_data(_world_snapshot)

func test_what_the_bag_cannot_hold_waits_and_adds_up() -> void:
	var drop := OverflowDrop.new()
	watch_signals(drop)
	assert_eq(drop.give(_stone, 3), 0, "a bag with room takes it all")
	assert_eq(drop.quantity, 0)
	assert_signal_not_emitted(drop, "changed", "nothing waits, nothing to save")
	assert_eq(drop.give(_stone, 4), 2, "a full stack leaves the rest")
	assert_eq(drop.quantity, 2)
	assert_signal_emitted(drop, "changed")
	assert_eq(drop.give(_stone, 3), 3)
	assert_eq(drop.quantity, 5, "what waits is every drop the bag could not take")
	assert_eq(drop.give(null, 3), 0, "no item, nothing given")
	assert_eq(InventoryState.get_quantity(&"fixture_stone"), 5)

func test_one_pile_lies_by_the_node_and_follows_what_is_taken() -> void:
	var source := _add_source(Vector2(40, 20))
	var drop := OverflowDrop.new(Vector2(10, 0))
	drop.show(source, _stone)
	assert_eq(_piles().size(), 0, "none waits, none lies there")
	InventoryState.add_item(_stone, 5)
	drop.give(_stone, 3)
	drop.show(source, _stone)
	drop.show(source, _stone)
	var piles := _piles()
	assert_eq(piles.size(), 1, "one pile, however often it is shown")
	if piles.is_empty():
		return
	var pile := piles[0]
	assert_eq(pile.quantity, 3)
	assert_eq(pile.global_position, Vector2(50, 20), "beside the node, by the drop's offset")
	assert_false(pile.counts_as_forage, "a drop is no forage")

	InventoryState.remove_item(&"fixture_stone", 2)
	watch_signals(drop)
	pile.get_node("Interactable").interact(null)
	assert_eq(pile.quantity, 1)
	assert_eq(drop.quantity, 1, "what the player took is no longer waiting")
	assert_signal_emitted(drop, "changed")

	drop.give(_stone, 2)
	drop.show(source, _stone)
	assert_eq(_piles().size(), 1, "more falls on the same pile")
	assert_eq(pile.quantity, 3)

	InventoryState.clear()
	pile.get_node("Interactable").interact(null)
	assert_eq(drop.quantity, 0)
	await get_tree().process_frame
	assert_eq(_piles().size(), 0, "taken whole, it is gone")
	drop.give(_stone, 9)
	drop.show(source, _stone)
	assert_eq(_piles().size(), 1, "and the next drop lays a new one")

func test_a_saved_count_is_any_whole_number_from_none_up() -> void:
	var drop := OverflowDrop.new()
	drop.load_count(999999)
	assert_eq(drop.quantity, 999999, "what waits may be many drops")
	drop.load_count(-10)
	assert_eq(drop.quantity, 0)
	drop.load_count("many")
	assert_eq(drop.quantity, 0)

func test_no_pile_lies_while_no_place_holds_it() -> void:
	var source := _add_source(Vector2.ZERO)
	InventoryState.add_item(_stone, 5)
	var drop := OverflowDrop.new()
	drop.give(_stone, 2)
	get_tree().current_scene = null
	drop.show(source, _stone)
	get_tree().current_scene = _place
	assert_eq(_piles().size(), 0)
	assert_eq(drop.quantity, 2, "it waits for the place to load")

func _add_source(at: Vector2) -> Node2D:
	var source := Node2D.new()
	_place.add_child(source)
	source.global_position = at
	return source

func _piles() -> Array[WorldItemPickup]:
	var piles: Array[WorldItemPickup] = []
	for child in _place.get_children():
		if child is WorldItemPickup and not child.is_queued_for_deletion():
			piles.append(child)
	return piles
