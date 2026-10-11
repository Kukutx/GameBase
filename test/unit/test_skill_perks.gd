extends GutTest

var _skill_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _world_snapshot: Dictionary
var _buff_snapshot: Dictionary
var _clock_snapshot: Dictionary

func before_each() -> void:
	_skill_snapshot = Skills.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	_buff_snapshot = BuffState.to_save_data()
	_clock_snapshot = WorldClock.to_save_data()
	Skills.reset_new_game()
	InventoryState.clear()
	PlayerState.reset_new_game()
	WorldState.clear()
	BuffState.clear()
	WorldClock.set_time(1, 8 * 60)

func after_each() -> void:
	Skills.load_save_data(_skill_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	WorldState.load_save_data(_world_snapshot)
	BuffState.load_save_data(_buff_snapshot)
	WorldClock.load_save_data(_clock_snapshot)

func test_skill_perks_unlock_at_levels_five_and_ten() -> void:
	var local := SkillManager.new()
	add_child_autofree(local)
	assert_eq(local.get_perk_tier(SkillManager.FARMING), 0)
	assert_eq(local.get_energy_multiplier(SkillManager.FARMING), 1.0)
	local.add_xp(SkillManager.FARMING, 700)
	assert_eq(local.get_level(SkillManager.FARMING), 5)
	assert_eq(local.get_perk_tier(SkillManager.FARMING), 1)
	assert_almost_eq(local.get_energy_multiplier(SkillManager.FARMING), 0.9, 0.001)
	local.add_xp(SkillManager.FARMING, 2500)
	assert_eq(local.get_level(SkillManager.FARMING), 10)
	assert_eq(local.get_perk_tier(SkillManager.FARMING), 2)
	assert_almost_eq(local.get_energy_multiplier(SkillManager.FARMING), 0.8, 0.001)
	assert_true(local.get_perk_summary(SkillManager.FARMING).contains("II"))

func test_farming_and_mining_perks_reduce_real_energy_costs() -> void:
	InventoryState.add_item_by_id(&"hoe", 1)
	var plot := load("res://gamebase/modules/lifesim/farming/farm_plot.tscn").instantiate() as FarmPlot
	plot.persistent_id = &""
	plot.hoe_energy_cost = 10
	add_child_autofree(plot)
	var hoe := ContentDB.get_item(&"hoe")
	assert_eq(plot.get_tool_energy_cost(hoe), 10)
	Skills.add_xp(SkillManager.FARMING, 700)
	assert_eq(plot.get_tool_energy_cost(hoe), 9)
	Skills.add_xp(SkillManager.FARMING, 2500)
	assert_eq(plot.get_tool_energy_cost(hoe), 8)

	Skills.reset_new_game()
	InventoryState.add_item_by_id(&"gold_pickaxe", 1)
	PlayerState.energy = 100
	var scene := load("res://gamebase/modules/lifesim/mining/mining_node.tscn") as PackedScene
	var rock1 := scene.instantiate() as MiningNode
	rock1.data = ContentDB.get_mining_node(&"iridium_rock")
	rock1.persistent_id = &""
	add_child_autofree(rock1)
	assert_true(rock1.use_item(&"gold_pickaxe"))
	assert_eq(PlayerState.energy, 92)

	Skills.add_xp(SkillManager.MINING, 700)
	PlayerState.energy = 100
	var rock5 := scene.instantiate() as MiningNode
	rock5.data = ContentDB.get_mining_node(&"iridium_rock")
	rock5.persistent_id = &""
	add_child_autofree(rock5)
	assert_true(rock5.use_item(&"gold_pickaxe"))
	assert_eq(PlayerState.energy, 93)

	Skills.add_xp(SkillManager.MINING, 2500)
	PlayerState.energy = 100
	var rock10 := scene.instantiate() as MiningNode
	rock10.data = ContentDB.get_mining_node(&"iridium_rock")
	rock10.persistent_id = &""
	add_child_autofree(rock10)
	assert_true(rock10.use_item(&"gold_pickaxe"))
	assert_eq(PlayerState.energy, 94)

func test_combat_and_fishing_perks_change_real_action_values() -> void:
	var melee := MeleeController.new()
	add_child_autofree(melee)
	var sword := ContentDB.get_item(&"copper_sword")
	assert_eq(melee.get_attack_damage(sword), 24)
	Skills.add_xp(SkillManager.COMBAT, 700)
	assert_eq(melee.get_attack_damage(sword), 26)
	Skills.add_xp(SkillManager.COMBAT, 2500)
	assert_eq(melee.get_attack_damage(sword), 30)

	Skills.reset_new_game()
	var fishing := FishingService.new()
	fishing.bite_window = 1.0
	add_child_autofree(fishing)
	assert_almost_eq(fishing.get_effective_wait_multiplier(), 1.0, 0.001)
	assert_almost_eq(fishing.get_effective_bite_window(), 1.0, 0.001)
	Skills.add_xp(SkillManager.FISHING, 700)
	assert_almost_eq(fishing.get_effective_wait_multiplier(), 0.9, 0.001)
	assert_almost_eq(fishing.get_effective_bite_window(), 1.15, 0.001)
	Skills.add_xp(SkillManager.FISHING, 2500)
	assert_almost_eq(fishing.get_effective_wait_multiplier(), 0.8, 0.001)
	assert_almost_eq(fishing.get_effective_bite_window(), 1.3, 0.001)

func test_social_and_foraging_perks_improve_rewards_without_changing_rng_plan() -> void:
	var profile := ContentDB.get_npc(&"mira")
	assert_not_null(profile)
	var state := RelationshipManager.new()
	add_child_autofree(state)
	InventoryState.add_item_by_id(&"berry", 3)
	assert_eq(state.give_gift(profile, &"berry"), 80)
	WorldClock.set_time(2, 8 * 60)
	Skills.add_xp(SkillManager.SOCIAL, 700)
	assert_eq(state.give_gift(profile, &"berry"), 88)
	WorldClock.set_time(3, 8 * 60)
	Skills.add_xp(SkillManager.SOCIAL, 2500)
	assert_eq(state.give_gift(profile, &"berry"), 96)

	Skills.reset_new_game()
	var spawner := ForageSpawner.new()
	spawner.spawner_id = &"perk_forage"
	spawner.location_id = &"starter_town"
	spawner.spawn_count = 4
	add_child_autofree(spawner)
	var base_plan := spawner.generate_plan(1)
	Skills.add_xp(SkillManager.FORAGING, 700)
	var level_five_plan := spawner.generate_plan(1)
	Skills.add_xp(SkillManager.FORAGING, 2500)
	var level_ten_plan := spawner.generate_plan(1)
	assert_eq(base_plan.size(), level_five_plan.size())
	assert_eq(base_plan.size(), level_ten_plan.size())
	for index in range(base_plan.size()):
		assert_eq(base_plan[index]["item_id"], level_five_plan[index]["item_id"])
		assert_eq(base_plan[index]["position"], level_five_plan[index]["position"])
		assert_eq(int(level_five_plan[index]["quantity"]), int(base_plan[index]["quantity"]) + 1)
		assert_eq(int(level_ten_plan[index]["quantity"]), int(base_plan[index]["quantity"]) + 2)
