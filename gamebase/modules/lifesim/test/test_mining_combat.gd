extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
## The vital the life-sim work spends here.
const ENERGY := &"fixture_energy"
const MINING_NODE_SCENE := preload("res://gamebase/modules/lifesim/mining/mining_node.tscn")

var _clock_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _vitals_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _world_snapshot: Dictionary
var _skill_snapshot: Dictionary
var _inventory_slots: int

func before_each() -> void:
	_clock_snapshot = WorldClock.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_vitals_snapshot = Vitals.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	_skill_snapshot = Skills.to_save_data()
	_inventory_slots = InventoryState.max_slots
	ContentFixture.use(self, _fixture_content() + [ContentFixture.vital(ENERGY)])
	_use_energy()
	InventoryState.clear()
	WorldState.clear()
	Vitals.reset_new_game()
	Skills.reset_new_game()
	InventoryState.add_item_by_id(&"fixture_pick", 1)

func after_each() -> void:
	# GUT frees the fixture content only after this method: restore the
	# services with the game's content, which their snapshots name.
	ContentRegistry.active = ContentDB
	WorldClock.load_save_data(_clock_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	Vitals.load_save_data(_vitals_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	WorldState.load_save_data(_world_snapshot)
	Skills.load_save_data(_skill_snapshot)
	InventoryState.max_slots = _inventory_slots

func test_loaded_mining_state_clamps_future_respawn_markers() -> void:
	WorldClock.set_time(10, 8 * 60)
	var node := _add_rock(&"")
	node.load_state_data({
		"durability_left": 999,
		"depleted": true,
		"depleted_day": 999999,
		"pending_drop_quantity": 999999,
	}, false)
	assert_true(node.is_depleted)
	assert_eq(node.depleted_day, 10)
	assert_eq(node.durability_left, 0)
	# Pending ground loot may legitimately aggregate multiple uncollected drops.
	# Preserve any non-negative saved quantity instead of truncating it to one node's base drop.
	assert_eq(node.pending_drop_quantity, 999999)
	node.load_state_data({"durability_left": 0, "depleted": false, "depleted_day": 999999, "pending_drop_quantity": -10}, false)
	assert_false(node.is_depleted)
	assert_eq(node.depleted_day, 0)
	assert_eq(node.durability_left, node.data.durability)
	assert_eq(node.pending_drop_quantity, 0)

func test_pick_breaks_rock_and_reports_the_mined_resource() -> void:
	var node := _add_rock(&"")
	watch_signals(LifesimEvents)

	assert_true(node.use_item(&"fixture_pick"))
	assert_eq(node.durability_left, 1)
	assert_true(node.use_item(&"fixture_pick"))
	assert_true(node.is_depleted)
	assert_eq(InventoryState.get_quantity(&"fixture_pebble"), 2)
	assert_signal_emit_count(LifesimEvents, "resource_mined", 1)
	assert_signal_emitted_with_parameters(LifesimEvents, "resource_mined", [&"fixture_rock", &"fixture_pebble", 2, node.global_position])

func test_mining_node_blocks_energy_and_drop_signal_reentrancy() -> void:
	var node := _add_rock(&"")
	await get_tree().process_frame

	var energy_observed := {"entered": false, "inner_result": true}
	var energy_listener := func(_vital_id: StringName, _current: int, _maximum: int) -> void:
		if bool(energy_observed["entered"]):
			return
		energy_observed["entered"] = true
		energy_observed["inner_result"] = node.use_item(&"fixture_pick")
	Vitals.changed.connect(energy_listener)
	assert_true(node.use_item(&"fixture_pick"))
	if Vitals.changed.is_connected(energy_listener):
		Vitals.changed.disconnect(energy_listener)
	assert_true(bool(energy_observed["entered"]))
	assert_false(bool(energy_observed["inner_result"]))
	assert_eq(node.durability_left, 1)
	assert_false(node.is_depleted)

	var drop_observed := {"entered": false, "inner_result": true}
	var item_listener := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"fixture_pebble" or bool(drop_observed["entered"]):
			return
		drop_observed["entered"] = true
		drop_observed["inner_result"] = node.use_item(&"fixture_pick")
	InventoryState.item_added.connect(item_listener)
	assert_true(node.use_item(&"fixture_pick"))
	if InventoryState.item_added.is_connected(item_listener):
		InventoryState.item_added.disconnect(item_listener)
	assert_true(bool(drop_observed["entered"]))
	assert_false(bool(drop_observed["inner_result"]))
	assert_true(node.is_depleted)
	assert_eq(InventoryState.get_quantity(&"fixture_pebble"), node.data.drop_quantity)

func test_mining_ground_drops_do_not_count_as_forage() -> void:
	InventoryState.clear()
	var node := _add_rock(&"")
	var pebble := ItemData.find(&"fixture_pebble")
	var mining_drop := node.call("_make_drop_pickup", pebble, 2) as WorldItemPickup
	assert_not_null(mining_drop)
	if mining_drop == null:
		return
	add_child_autofree(mining_drop)
	await get_tree().process_frame
	assert_false(mining_drop.counts_as_forage)
	watch_signals(ItemsEvents)
	mining_drop.get_node("Interactable").interact(null)
	await get_tree().process_frame
	assert_eq(InventoryState.get_quantity(&"fixture_pebble"), 2)
	assert_signal_not_emitted(ItemsEvents, "item_foraged")

func test_pending_ground_loot_survives_partial_collection_and_source_reload() -> void:
	InventoryState.clear()
	InventoryState.max_slots = 1
	var pebble := ItemData.find(&"fixture_pebble")
	InventoryState.add_item(pebble, pebble.max_stack - 1)
	var node := _add_rock(&"fixture_pending_rock")
	await get_tree().process_frame
	node.load_state_data({
		"durability_left": 0,
		"depleted": true,
		"depleted_day": WorldClock.day,
		"pending_drop_quantity": 2,
	})
	var pickup := node.call("_make_drop_pickup", pebble, 2) as WorldItemPickup
	assert_not_null(pickup)
	if pickup == null:
		return
	pickup.items_collected.connect(Callable(node, "_on_pending_drop_collected"))
	add_child_autofree(pickup)
	await get_tree().process_frame
	pickup.get_node("Interactable").interact(null)
	await get_tree().process_frame
	assert_eq(InventoryState.get_quantity(&"fixture_pebble"), pebble.max_stack)
	assert_eq(pickup.quantity, 1)
	assert_eq(node.pending_drop_quantity, 1)
	var saved_state := WorldState.get_value(&"mining:fixture_pending_rock", {}) as Dictionary
	assert_eq(int(saved_state.get("pending_drop_quantity", 0)), 1)

	var restored := _add_rock(&"fixture_pending_rock")
	await get_tree().process_frame
	assert_eq(restored.pending_drop_quantity, 1)

func _add_rock(persistent_id: StringName) -> MiningNode:
	var node := MINING_NODE_SCENE.instantiate() as MiningNode
	node.data = MiningNodeData.find(&"fixture_rock")
	node.persistent_id = persistent_id
	add_child_autofree(node)
	return node

# A pick of power 1 and a rock that takes two hits, costs 3 energy a hit and
# drops two pebbles.
func _fixture_content() -> Array:
	var pick := ItemData.new()
	pick.id = &"fixture_pick"
	pick.display_name = "Pick"
	pick.kind = ItemData.Kind.TOOL
	pick.max_stack = 1
	pick.tool_action = MiningNode.TOOL_ACTION
	pick.tool_power = 1
	var pebble := ItemData.new()
	pebble.id = &"fixture_pebble"
	pebble.display_name = "Pebble"
	pebble.tags = PackedStringArray(["mined"])
	var rock := MiningNodeData.new()
	rock.id = &"fixture_rock"
	rock.display_name = "Rock"
	rock.durability = 2
	rock.energy_cost = 3
	rock.drop_item_id = pebble.id
	rock.drop_quantity = 2
	rock.respawn_days = 1
	return [pick, pebble, rock]

# Makes `ENERGY` the vital the life-sim work spends.
func _use_energy() -> void:
	var settings := LifesimSettings.new()
	settings.energy_vital_id = ENERGY
	ContentFixture.use_settings(self, [settings])
