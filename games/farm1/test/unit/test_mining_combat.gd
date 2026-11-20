extends GutTest

var _inventory_snapshot: Dictionary
var _vitals_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _world_snapshot: Dictionary
var _skill_snapshot: Dictionary

func before_each() -> void:
	_inventory_snapshot = InventoryState.to_save_data()
	_vitals_snapshot = Vitals.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	_skill_snapshot = Skills.to_save_data()
	InventoryState.clear()
	WorldState.clear()
	Vitals.reset_new_game()
	Skills.reset_new_game()
	InventoryState.add_item_by_id(&"pickaxe", 1)
	InventoryState.add_item_by_id(&"rusty_sword", 1)

func after_each() -> void:
	InventoryState.load_save_data(_inventory_snapshot)
	Vitals.load_save_data(_vitals_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	WorldState.load_save_data(_world_snapshot)
	Skills.load_save_data(_skill_snapshot)

func test_pickaxe_breaks_stone_and_awards_mining_xp() -> void:
	var scene := load("res://tiamat/modules/lifesim/mining/mining_node.tscn") as PackedScene
	var node := scene.instantiate() as MiningNode
	node.data = MiningNodeData.find(&"stone_rock")
	node.persistent_id = &""
	add_child_autofree(node)

	assert_true(node.use_item(&"pickaxe"))
	assert_eq(node.durability_left, 1)
	assert_true(node.use_item(&"pickaxe"))
	assert_true(node.is_depleted)
	assert_eq(InventoryState.get_quantity(&"stone"), 2)
	assert_eq(Skills.get_xp(&"mining"), 24)

func test_slime_takes_melee_damage_drops_loot_and_awards_combat_xp() -> void:
	var scene := load("res://tiamat/modules/combat/combat/hostile_creature.tscn") as PackedScene
	var slime := scene.instantiate() as HostileCreature
	slime.data = EnemyData.find(&"green_slime")
	slime.persistent_id = &""
	slime.global_position = Vector2(10000, 10000)
	add_child_autofree(slime)

	assert_true(slime.take_damage(15))
	assert_eq(slime.health.current, 15)
	assert_true(slime.take_damage(15))
	assert_true(slime.is_defeated)
	assert_eq(InventoryState.get_quantity(&"slime_gel"), 1)
	assert_eq(Skills.get_xp(&"combat"), 20)

func test_a_slingshot_from_the_store_flings_pebbles_at_the_nearest_slime_ahead() -> void:
	assert_eq(ShopData.find(&"general_store").get_stock("Spring").get("slingshot"), 900, "the general store sells it")
	var player := (load("res://game/player/player.tscn") as PackedScene).instantiate() as TopDownPlayer
	player.global_position = Vector2(12000, 12000)
	add_child_autofree(player)
	var sling := player.get_node("RangedAttack") as RangedAttack
	assert_eq(sling.action, &"use_tool", "on the tool control, like the swords")
	InventoryState.add_item_by_id(&"slingshot", 1)
	Hotbar.set_slot_item(0, &"slingshot")
	Hotbar.select_slot(0)
	var slime := (load("res://tiamat/modules/combat/combat/hostile_creature.tscn") as PackedScene).instantiate() as HostileCreature
	slime.data = EnemyData.find(&"green_slime")
	slime.persistent_id = &""
	slime.global_position = Vector2(12070, 12010)
	add_child_autofree(slime)
	player.face(Vector2.RIGHT)
	await wait_physics_frames(2)
	var health := slime.health.current
	assert_true(sling.shoot_selected_weapon())
	assert_true(await wait_until(func() -> bool: return slime.health.current < health, 1.0), "the pebble finds the slime a little off the way the player faces")
