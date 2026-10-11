extends GutTest

var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _world_snapshot: Dictionary
var _skill_snapshot: Dictionary
var _inventory_slots: int

func before_each() -> void:
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	_skill_snapshot = Skills.to_save_data()
	_inventory_slots = InventoryState.max_slots
	InventoryState.clear()
	WorldState.clear()
	PlayerState.reset_new_game()
	Skills.reset_new_game()
	InventoryState.add_item_by_id(&"pickaxe", 1)
	InventoryState.add_item_by_id(&"rusty_sword", 1)

func after_each() -> void:
	InventoryState.load_save_data(_inventory_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	WorldState.load_save_data(_world_snapshot)
	Skills.load_save_data(_skill_snapshot)
	InventoryState.max_slots = _inventory_slots

func test_loaded_mining_and_enemy_state_clamps_future_respawn_markers() -> void:
	WorldClock.set_time(10, 8 * 60)
	var mining_scene := load("res://gamebase/modules/lifesim/mining/mining_node.tscn") as PackedScene
	var node := mining_scene.instantiate() as MiningNode
	node.data = MiningNodeData.find(&"stone_rock")
	node.persistent_id = &""
	add_child_autofree(node)
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

	var enemy_scene := load("res://gamebase/modules/combat/combat/hostile_creature.tscn") as PackedScene
	var enemy := enemy_scene.instantiate() as HostileCreature
	enemy.data = EnemyData.find(&"green_slime")
	enemy.persistent_id = &""
	add_child_autofree(enemy)
	enemy.load_state_data({"health": 999, "defeated": true, "defeated_day": 999999, "pending_drop_quantity": 999999}, false)
	assert_true(enemy.is_defeated)
	assert_eq(enemy.defeated_day, 10)
	assert_eq(enemy.health, 0)
	assert_eq(enemy.pending_drop_quantity, 999999)
	enemy.load_state_data({"health": 0, "defeated": false, "defeated_day": 999999, "pending_drop_quantity": -10}, false)
	assert_false(enemy.is_defeated)
	assert_eq(enemy.defeated_day, 0)
	assert_eq(enemy.health, enemy.data.max_health)
	assert_eq(enemy.pending_drop_quantity, 0)

func test_pickaxe_breaks_stone_and_awards_mining_xp() -> void:
	var scene := load("res://gamebase/modules/lifesim/mining/mining_node.tscn") as PackedScene
	var node = scene.instantiate()
	node.data = MiningNodeData.find(&"stone_rock")
	node.persistent_id = &""
	add_child_autofree(node)

	assert_true(node.use_item(&"pickaxe"))
	assert_eq(node.durability_left, 1)
	assert_true(node.use_item(&"pickaxe"))
	assert_true(node.is_depleted)
	assert_eq(InventoryState.get_quantity(&"stone"), 2)
	assert_eq(Skills.get_xp(&"mining"), 24)

func test_mining_node_blocks_energy_and_drop_signal_reentrancy() -> void:
	var scene := load("res://gamebase/modules/lifesim/mining/mining_node.tscn") as PackedScene
	var node := scene.instantiate() as MiningNode
	node.data = MiningNodeData.find(&"stone_rock")
	node.persistent_id = &""
	add_child_autofree(node)
	await get_tree().process_frame

	var energy_observed := {"entered": false, "inner_result": true}
	var energy_listener := func(_current: int, _maximum: int) -> void:
		if bool(energy_observed["entered"]):
			return
		energy_observed["entered"] = true
		energy_observed["inner_result"] = node.use_item(&"pickaxe")
	PlayerState.energy_changed.connect(energy_listener)
	assert_true(node.use_item(&"pickaxe"))
	if PlayerState.energy_changed.is_connected(energy_listener):
		PlayerState.energy_changed.disconnect(energy_listener)
	assert_true(bool(energy_observed["entered"]))
	assert_false(bool(energy_observed["inner_result"]))
	assert_eq(node.durability_left, 1)
	assert_false(node.is_depleted)

	var drop_observed := {"entered": false, "inner_result": true}
	var item_listener := func(item_id: StringName, _quantity: int) -> void:
		if item_id != &"stone" or bool(drop_observed["entered"]):
			return
		drop_observed["entered"] = true
		drop_observed["inner_result"] = node.use_item(&"pickaxe")
	InventoryState.item_added.connect(item_listener)
	assert_true(node.use_item(&"pickaxe"))
	if InventoryState.item_added.is_connected(item_listener):
		InventoryState.item_added.disconnect(item_listener)
	assert_true(bool(drop_observed["entered"]))
	assert_false(bool(drop_observed["inner_result"]))
	assert_true(node.is_depleted)
	assert_eq(InventoryState.get_quantity(&"stone"), node.data.drop_quantity)

func test_mining_and_enemy_ground_drops_do_not_count_as_forage() -> void:
	InventoryState.clear()
	var mining_scene := load("res://gamebase/modules/lifesim/mining/mining_node.tscn") as PackedScene
	var node = mining_scene.instantiate()
	node.data = MiningNodeData.find(&"stone_rock")
	node.persistent_id = &""
	add_child_autofree(node)
	var stone := ItemData.find(&"stone")
	var mining_drop := node.call("_make_drop_pickup", stone, 2) as WorldItemPickup
	assert_not_null(mining_drop)
	if mining_drop != null:
		add_child_autofree(mining_drop)
		await get_tree().process_frame
		assert_false(mining_drop.counts_as_forage)
		var forage_xp_before := Skills.get_xp(&"foraging")
		mining_drop.get_node("Interactable").interact(null)
		await get_tree().process_frame
		assert_eq(InventoryState.get_quantity(&"stone"), 2)
		assert_eq(Skills.get_xp(&"foraging"), forage_xp_before)

	InventoryState.clear()
	var creature_scene := load("res://gamebase/modules/combat/combat/hostile_creature.tscn") as PackedScene
	var slime = creature_scene.instantiate()
	slime.data = EnemyData.find(&"green_slime")
	slime.persistent_id = &""
	add_child_autofree(slime)
	var gel := ItemData.find(&"slime_gel")
	var enemy_drop := slime.call("_make_drop_pickup", gel, 1) as WorldItemPickup
	assert_not_null(enemy_drop)
	if enemy_drop != null:
		assert_false(enemy_drop.counts_as_forage)
		enemy_drop.free()

func test_pending_ground_loot_survives_partial_collection_and_source_reload() -> void:
	InventoryState.clear()
	InventoryState.max_slots = 1
	var stone := ItemData.find(&"stone")
	assert_not_null(stone)
	if stone == null:
		return
	InventoryState.add_item(stone, stone.max_stack - 1)
	var mining_scene := load("res://gamebase/modules/lifesim/mining/mining_node.tscn") as PackedScene
	var node = mining_scene.instantiate() as MiningNode
	node.data = MiningNodeData.find(&"stone_rock")
	node.persistent_id = &"pending_mining_test"
	add_child_autofree(node)
	await get_tree().process_frame
	node.load_state_data({
		"durability_left": 0,
		"depleted": true,
		"depleted_day": WorldClock.day,
		"pending_drop_quantity": 2,
	})
	var pickup := node.call("_make_drop_pickup", stone, 2) as WorldItemPickup
	assert_not_null(pickup)
	if pickup == null:
		return
	pickup.items_collected.connect(Callable(node, "_on_pending_drop_collected"))
	add_child_autofree(pickup)
	await get_tree().process_frame
	pickup.get_node("Interactable").interact(null)
	await get_tree().process_frame
	assert_eq(InventoryState.get_quantity(&"stone"), stone.max_stack)
	assert_eq(pickup.quantity, 1)
	assert_eq(node.pending_drop_quantity, 1)
	var saved_state := WorldState.get_value(&"mining:pending_mining_test", {}) as Dictionary
	assert_eq(int(saved_state.get("pending_drop_quantity", 0)), 1)

	var restored = mining_scene.instantiate() as MiningNode
	restored.data = MiningNodeData.find(&"stone_rock")
	restored.persistent_id = &"pending_mining_test"
	add_child_autofree(restored)
	await get_tree().process_frame
	assert_eq(restored.pending_drop_quantity, 1)

	var enemy_scene := load("res://gamebase/modules/combat/combat/hostile_creature.tscn") as PackedScene
	var enemy = enemy_scene.instantiate() as HostileCreature
	enemy.data = EnemyData.find(&"green_slime")
	enemy.persistent_id = &"pending_enemy_test"
	add_child_autofree(enemy)
	await get_tree().process_frame
	enemy.load_state_data({
		"health": 0,
		"defeated": true,
		"defeated_day": WorldClock.day,
		"pending_drop_quantity": 3,
	})
	assert_eq(enemy.pending_drop_quantity, 3)
	var enemy_saved := WorldState.get_value(&"enemy:pending_enemy_test", {}) as Dictionary
	assert_eq(int(enemy_saved.get("pending_drop_quantity", 0)), 3)

func test_melee_attack_blocks_energy_changed_reentrancy() -> void:
	Hotbar.set_slot_item(0, &"rusty_sword")
	Hotbar.select_slot(0)
	PlayerState.energy = 100
	var controller := MeleeController.new()
	add_child_autofree(controller)
	var observed := {"entered": false, "inner_result": true}
	var listener := func(_current: int, _maximum: int) -> void:
		if bool(observed["entered"]):
			return
		observed["entered"] = true
		observed["inner_result"] = controller.attack_selected_weapon()
	PlayerState.energy_changed.connect(listener)
	assert_true(controller.attack_selected_weapon())
	if PlayerState.energy_changed.is_connected(listener):
		PlayerState.energy_changed.disconnect(listener)
	assert_true(bool(observed["entered"]))
	assert_false(bool(observed["inner_result"]))
	var expected_cost := maxi(int(floor(float(controller.energy_cost) * GameStats.get_multiplier(&"tool_energy") * GameStats.get_multiplier(&"attack_energy"))), 1)
	assert_eq(PlayerState.energy, 100 - expected_cost)

func test_slime_takes_melee_damage_drops_loot_and_awards_combat_xp() -> void:
	var scene := load("res://gamebase/modules/combat/combat/hostile_creature.tscn") as PackedScene
	var slime = scene.instantiate()
	slime.data = EnemyData.find(&"green_slime")
	slime.persistent_id = &""
	slime.global_position = Vector2(10000, 10000)
	add_child_autofree(slime)

	assert_true(slime.take_damage(15))
	assert_eq(slime.health, 15)
	assert_true(slime.take_damage(15))
	assert_true(slime.is_defeated)
	assert_eq(InventoryState.get_quantity(&"slime_gel"), 1)
	assert_eq(Skills.get_xp(&"combat"), 20)
