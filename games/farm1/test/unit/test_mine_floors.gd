extends GutTest

var _world_snapshot: Dictionary
var _clock_day: int
var _clock_minute: int
var _seed: int

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_clock_day = WorldClock.day
	_clock_minute = WorldClock.minute_of_day
	_seed = WeatherState.world_seed
	WorldState.clear()
	WorldState.set_value(GameSession.NEW_GAME_FLAG, true)
	WorldClock.set_time(1, 8 * 60)
	WeatherState.world_seed = 93017
	MineState.enter_from_surface()

func after_each() -> void:
	WorldState.load_save_data(_world_snapshot)
	WorldClock.set_time(_clock_day, _clock_minute)
	WeatherState.world_seed = _seed

func test_the_game_mine_floor_table_names_real_content() -> void:
	assert_not_null(MineState.floor_table)
	assert_eq(MineState.floor_table.find_problems(ContentDB), PackedStringArray())
	assert_eq(MineState.floor_table.get_enemy_id(1), &"green_slime")
	assert_eq(MineState.floor_table.get_enemy_id(59), &"red_slime")

func test_deep_floors_guarantee_iron_and_cave_slime_progression() -> void:
	var floor5 := MineState.generate_floor_layout(5)
	var floor6_a := MineState.generate_floor_layout(6)
	var floor6_b := MineState.generate_floor_layout(6)
	var floor10 := MineState.generate_floor_layout(10)
	assert_eq(floor6_a, floor6_b)
	var floor5_kinds: Array[String] = []
	for entry: Dictionary in floor5["rocks"]:
		floor5_kinds.append(String(entry["kind"]))
	assert_false(floor5_kinds.has("iron_rock"))
	var floor6_kinds: Array[String] = []
	for entry: Dictionary in floor6_a["rocks"]:
		floor6_kinds.append(String(entry["kind"]))
	assert_true(floor6_kinds.has("iron_rock"))
	var floor10_enemies: Array[String] = []
	for entry: Dictionary in floor10["enemies"]:
		floor10_enemies.append(String(entry["kind"]))
	assert_true(floor10_enemies.has("cave_slime"))
	assert_eq(MiningNodeData.find(&"iron_rock").required_tool_power, 2)
	assert_eq(MiningNodeData.find(&"iron_rock").drop_item_id, &"iron_ore")
	assert_eq(EnemyData.find(&"cave_slime").contact_damage, 12)

func test_floor_six_scene_maps_generated_iron_to_real_iron_node_data() -> void:
	MineState.set_floor(6)
	var packed := load("res://game/world/old_mine.tscn") as PackedScene
	var mine := packed.instantiate() as MineFloorController
	add_child_autofree(mine)
	await get_tree().process_frame
	await get_tree().process_frame
	var found_iron := false
	for rock: MiningNode in mine.get_generated_rocks():
		if rock.data != null and rock.data.id == &"iron_rock":
			found_iron = true
			break
	assert_true(found_iron)

func test_floor_ten_scene_maps_cave_slime_to_stronger_enemy_data() -> void:
	MineState.set_floor(10)
	var packed := load("res://game/world/old_mine.tscn") as PackedScene
	var mine := packed.instantiate() as MineFloorController
	add_child_autofree(mine)
	await get_tree().process_frame
	await get_tree().process_frame
	var found_cave_slime := false
	for enemy: HostileCreature in mine.get_generated_enemies():
		if enemy.data != null and enemy.data.id == &"cave_slime":
			found_cave_slime = true
			break
	assert_true(found_cave_slime)

func test_dynamic_mine_floor_spawns_and_unlocks_ladder_only_after_clear() -> void:
	MineState.set_floor(2)
	var packed := load("res://game/world/old_mine.tscn") as PackedScene
	var mine := packed.instantiate() as MineFloorController
	add_child_autofree(mine)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(mine.current_floor, 2)
	assert_null(mine.get_node_or_null("StoneRockA"))
	assert_gt(mine.get_generated_rocks().size(), 0)
	assert_gt(mine.get_generated_enemies().size(), 0)
	var ladder := mine.get_node("DeepLadder") as MineLadder
	assert_false(ladder.unlocked)

	for rock: MiningNode in mine.get_generated_rocks():
		rock.load_state_data({"durability_left": 0, "depleted": true, "depleted_day": WorldClock.day})
	for enemy: HostileCreature in mine.get_generated_enemies():
		enemy.load_state_data({"health": 0, "defeated": true, "defeated_day": WorldClock.day})
	mine.call("_refresh_ladder")
	assert_true(mine.is_floor_cleared())
	assert_true(ladder.unlocked)

func test_mine_scene_routes_its_ladder_and_elevator_through_its_own_location() -> void:
	var mine := (load("res://game/world/old_mine.tscn") as PackedScene).instantiate() as MineFloorController
	add_child_autofree(mine)
	assert_eq(mine.entrance_spawn_ids, [&"from_riverside"] as Array[StringName])
	assert_eq(mine.floor_spawn_id, &"floor_entry")
	assert_true(ContentDB.has_location_spawn(&"old_mine", mine.floor_spawn_id))
	assert_eq(ContentDB.get_location_for_scene(mine.scene_file_path).id, &"old_mine")
	assert_eq((mine.get_node("DeepLadder") as MineLadder).mine, mine)
	assert_eq((mine.get_node("MineElevator") as MineElevator).mine, mine)

func test_failed_mine_travel_does_not_commit_floor_change() -> void:
	MineState.set_floor(5)
	var deepest_before := MineState.get_deepest_floor()
	var previous_traveling := WorldTravel.is_traveling()
	var mine := (load("res://game/world/old_mine.tscn") as PackedScene).instantiate() as MineFloorController
	add_child_autofree(mine)
	WorldTravel.set("_traveling", true)

	var ladder := mine.get_node("DeepLadder") as MineLadder
	ladder.set_unlocked(true)
	ladder.call("_on_interacted", null)
	var floor_after_ladder := MineState.get_current_floor()
	var deepest_after_ladder := MineState.get_deepest_floor()

	var elevator := mine.get_node("MineElevator") as MineElevator
	elevator.call("_on_interacted", null)
	var floor_after_elevator := MineState.get_current_floor()
	WorldTravel.set("_traveling", previous_traveling)

	assert_eq(floor_after_ladder, 5)
	assert_eq(deepest_after_ladder, deepest_before)
	assert_eq(floor_after_elevator, 5)

func test_mine_progression_content_is_registered() -> void:
	for item_id: StringName in [&"iron_ore", &"iron_bar", &"iron_hoe", &"iron_watering_can", &"iron_pickaxe", &"iron_sword", &"gold_ore", &"gold_bar", &"gold_hoe", &"gold_watering_can", &"gold_pickaxe", &"gold_sword", &"iridium_ore", &"iridium_bar", &"iridium_hoe", &"iridium_watering_can", &"iridium_pickaxe", &"iridium_sword"]:
		assert_not_null(ItemData.find(item_id), "Missing mine progression item %s" % item_id)
	for node_id: StringName in [&"iron_rock", &"gold_rock", &"iridium_rock"]:
		assert_not_null(MiningNodeData.find(node_id), "Missing mine node %s" % node_id)
	for enemy_id: StringName in [&"cave_slime", &"blue_slime", &"red_slime", &"shadow_slime", &"void_slime", &"ancient_slime"]:
		assert_not_null(EnemyData.find(enemy_id), "Missing mine enemy %s" % enemy_id)
	for recipe_id: StringName in [&"smelt_iron_bar", &"smelt_gold_bar", &"smelt_iridium_bar"]:
		assert_not_null(ProcessingRecipeData.find(recipe_id), "Missing metal recipe %s" % recipe_id)
	for upgrade_id: StringName in [&"iron_hoe_upgrade", &"iron_watering_can_upgrade", &"iron_pickaxe_upgrade", &"iron_sword_upgrade", &"gold_hoe_upgrade", &"gold_watering_can_upgrade", &"gold_pickaxe_upgrade", &"gold_sword_upgrade", &"iridium_hoe_upgrade", &"iridium_watering_can_upgrade", &"iridium_pickaxe_upgrade", &"iridium_sword_upgrade"]:
		assert_not_null(ToolUpgradeData.find(upgrade_id), "Missing mine progression upgrade %s" % upgrade_id)

func test_gold_and_deep_slime_tiers_unlock_at_defined_floors() -> void:
	var floor19 := MineState.generate_floor_layout(19)
	var floor20 := MineState.generate_floor_layout(20)
	var floor40 := MineState.generate_floor_layout(40)
	var floor19_rocks: Array[String] = []
	for entry: Dictionary in floor19["rocks"]:
		floor19_rocks.append(String(entry["kind"]))
	assert_false(floor19_rocks.has("gold_rock"))
	var floor20_rocks: Array[String] = []
	for entry: Dictionary in floor20["rocks"]:
		floor20_rocks.append(String(entry["kind"]))
	assert_true(floor20_rocks.has("gold_rock"))
	for entry: Dictionary in floor20["enemies"]:
		assert_eq(String(entry["kind"]), "blue_slime")
	for entry: Dictionary in floor40["enemies"]:
		assert_eq(String(entry["kind"]), "red_slime")
	assert_eq(MiningNodeData.find(&"gold_rock").required_tool_power, 3)
	assert_eq(MiningNodeData.find(&"gold_rock").drop_item_id, &"gold_ore")
	assert_gt(EnemyData.find(&"red_slime").max_health, EnemyData.find(&"blue_slime").max_health)

func test_floor_twenty_scene_maps_gold_and_blue_slime_to_real_data() -> void:
	MineState.set_floor(20)
	var packed := load("res://game/world/old_mine.tscn") as PackedScene
	var mine := packed.instantiate() as MineFloorController
	add_child_autofree(mine)
	await get_tree().process_frame
	await get_tree().process_frame
	var found_gold := false
	for rock: MiningNode in mine.get_generated_rocks():
		if rock.data != null and rock.data.id == &"gold_rock":
			found_gold = true
			break
	assert_true(found_gold)
	for enemy: HostileCreature in mine.get_generated_enemies():
		assert_eq(enemy.data.id, &"blue_slime")

func test_floor_forty_scene_uses_red_slime_tier() -> void:
	MineState.set_floor(40)
	var packed := load("res://game/world/old_mine.tscn") as PackedScene
	var mine := packed.instantiate() as MineFloorController
	add_child_autofree(mine)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gt(mine.get_generated_enemies().size(), 0)
	for enemy: HostileCreature in mine.get_generated_enemies():
		assert_eq(enemy.data.id, &"red_slime")

func test_iridium_and_endgame_enemy_tiers_unlock_at_floors_sixty_ninety_and_one_twenty() -> void:
	var floor59 := MineState.generate_floor_layout(59)
	var floor60 := MineState.generate_floor_layout(60)
	var floor90 := MineState.generate_floor_layout(90)
	var floor120 := MineState.generate_floor_layout(120)
	var floor59_rocks: Array[String] = []
	for entry: Dictionary in floor59["rocks"]:
		floor59_rocks.append(String(entry["kind"]))
	assert_false(floor59_rocks.has("iridium_rock"))
	var floor60_rocks: Array[String] = []
	for entry: Dictionary in floor60["rocks"]:
		floor60_rocks.append(String(entry["kind"]))
	assert_true(floor60_rocks.has("iridium_rock"))
	assert_eq(String((floor60["rocks"] as Array)[0]["kind"]), "iridium_rock")
	for entry: Dictionary in floor60["enemies"]:
		assert_eq(String(entry["kind"]), "shadow_slime")
	for entry: Dictionary in floor90["enemies"]:
		assert_eq(String(entry["kind"]), "void_slime")
	for entry: Dictionary in floor120["enemies"]:
		assert_eq(String(entry["kind"]), "ancient_slime")
	assert_eq(MiningNodeData.find(&"iridium_rock").required_tool_power, 4)
	assert_eq(MiningNodeData.find(&"iridium_rock").drop_item_id, &"iridium_ore")
	assert_gt(EnemyData.find(&"ancient_slime").max_health, EnemyData.find(&"void_slime").max_health)

func test_floor_sixty_scene_maps_iridium_and_shadow_slime_to_real_data() -> void:
	MineState.set_floor(60)
	var packed := load("res://game/world/old_mine.tscn") as PackedScene
	var mine := packed.instantiate() as MineFloorController
	add_child_autofree(mine)
	await get_tree().process_frame
	await get_tree().process_frame
	var found_iridium := false
	for rock: MiningNode in mine.get_generated_rocks():
		if rock.data != null and rock.data.id == &"iridium_rock":
			found_iridium = true
			break
	assert_true(found_iridium)
	for enemy: HostileCreature in mine.get_generated_enemies():
		assert_eq(enemy.data.id, &"shadow_slime")

func test_floor_one_twenty_uses_ancient_slimes_and_never_unlocks_deeper_ladder() -> void:
	MineState.set_floor(120)
	var packed := load("res://game/world/old_mine.tscn") as PackedScene
	var mine := packed.instantiate() as MineFloorController
	add_child_autofree(mine)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_gt(mine.get_generated_enemies().size(), 0)
	for enemy: HostileCreature in mine.get_generated_enemies():
		assert_eq(enemy.data.id, &"ancient_slime")
	for rock: MiningNode in mine.get_generated_rocks():
		rock.load_state_data({"durability_left": 0, "depleted": true, "depleted_day": WorldClock.day})
	for enemy: HostileCreature in mine.get_generated_enemies():
		enemy.load_state_data({"health": 0, "defeated": true, "defeated_day": WorldClock.day})
	mine.call("_refresh_ladder")
	assert_true(mine.is_floor_cleared())
	assert_false((mine.get_node("DeepLadder") as MineLadder).unlocked)
