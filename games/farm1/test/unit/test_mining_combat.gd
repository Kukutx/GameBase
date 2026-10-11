extends GutTest

var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _world_snapshot: Dictionary
var _skill_snapshot: Dictionary

func before_each() -> void:
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	_skill_snapshot = Skills.to_save_data()
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
