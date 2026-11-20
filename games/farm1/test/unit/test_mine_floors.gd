extends GutTest

var _world_snapshot: Dictionary
var _clock_day: int
var _clock_minute: int
var _seed: int

func before_each() -> void:
	_world_snapshot = WorldState.to_save_data()
	_clock_day = WorldClock.day
	_clock_minute = WorldClock.minute_of_day
	_seed = GameRandom.world_seed
	WorldState.clear()
	WorldState.set_value(GameSession.NEW_GAME_FLAG, true)
	WorldClock.set_time(1, 8 * 60)
	GameRandom.set_seed(93017)
	MineState.enter_from_surface()

func after_each() -> void:
	WorldState.load_save_data(_world_snapshot)
	WorldClock.set_time(_clock_day, _clock_minute)
	GameRandom.set_seed(_seed)

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
	assert_eq(WorldLocationData.find_for_scene(mine.scene_file_path).id, &"old_mine")
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

func test_spitting_slimes_come_among_the_blue_slimes_of_floors_twenty_one_to_thirty_nine() -> void:
	var counts := {}
	for floor: int in range(21, 40):
		for entry: Dictionary in MineState.generate_floor_layout(floor)["enemies"]:
			if not entry.has("guardian"):
				counts[String(entry["kind"])] = int(counts.get(String(entry["kind"]), 0)) + 1
	assert_eq(counts.keys().size(), 2, "only the two kinds: %s" % [counts])
	var spitters := int(counts.get("spitting_slime", 0))
	var share := float(spitters) / float(spitters + int(counts.get("blue_slime", 0)))
	assert_between(share, 0.15, 0.45, "about a third")
	for floor: int in [20, 40]:
		for entry: Dictionary in MineState.generate_floor_layout(floor)["enemies"]:
			assert_ne(String(entry["kind"]), "spitting_slime", "floor %d" % floor)
	var spitter := EnemyData.find(&"spitting_slime")
	assert_gt(spitter.shot_speed, 0.0, "it spits from afar")
	assert_gt(spitter.attack_range, EnemyData.find(&"blue_slime").attack_range * 3.0)

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

func test_magma_vents_flare_from_floor_forty_under_the_player_more_of_them_deeper() -> void:
	var spread := MineState.floor_table.hazards
	assert_eq(spread.count_at(39), 0, "none above floor forty")
	assert_eq(spread.count_at(40), 1)
	assert_eq(spread.count_at(60), 2)
	assert_eq(spread.count_at(120), 3, "three at most")
	assert_eq(MineState.generate_floor_layout(39)["hazards"], [])
	MineState.set_floor(80)
	var mine := (load("res://game/world/old_mine.tscn") as PackedScene).instantiate() as MineFloorController
	add_child_autofree(mine)
	await get_tree().process_frame
	await get_tree().process_frame
	var vents := mine.get_generated_hazards()
	assert_eq(vents.size(), 3)
	var player := mine.get_node("Player")
	for vent: Hazard in vents:
		assert_eq(vent.damage, 20, "burning harder the deeper")
		assert_lt(vent.get_index(), player.get_index(), "under the player")
		for rock: MiningNode in mine.get_generated_rocks():
			assert_gte(vent.position.distance_to(rock.position), spread.spacing, "clear of the rocks")

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

func test_a_slime_king_and_then_a_void_monarch_guard_every_twenty_fifth_floor() -> void:
	var table := MineState.floor_table
	for floor: int in [25, 50]:
		assert_eq(table.get_guardian_ids(floor), [&"slime_king"] as Array[StringName], "floor %d" % floor)
	for floor: int in [75, 100]:
		assert_eq(table.get_guardian_ids(floor), [&"void_monarch"] as Array[StringName], "floor %d" % floor)
	for floor: int in [2, 20, 24, 26, 40, 60, 90, 120]:
		assert_eq(table.get_guardian_ids(floor), [] as Array[StringName], "floor %d" % floor)
	assert_gt(EnemyData.find(&"slime_king").max_health, EnemyData.find(&"red_slime").max_health, "stronger than the floors it guards")
	assert_gt(EnemyData.find(&"void_monarch").max_health, EnemyData.find(&"void_slime").max_health)

func test_a_guardian_bars_the_ladder_until_it_falls() -> void:
	MineState.set_floor(25)
	var mine := (load("res://game/world/old_mine.tscn") as PackedScene).instantiate() as MineFloorController
	add_child_autofree(mine)
	await get_tree().process_frame
	await get_tree().process_frame
	var guardians := mine.get_generated_guardians()
	assert_eq(guardians.size(), 1)
	assert_eq(guardians[0].data.id, &"slime_king")
	assert_eq(String(guardians[0].name), "GeneratedGuardian01")
	assert_true(mine.get_generated_enemies().has(guardians[0]))
	assert_eq(mine.get_place_detail(), "Floor 25", "the HUD tells the floor")
	for rock: MiningNode in mine.get_generated_rocks():
		rock.load_state_data({"durability_left": 0, "depleted": true, "depleted_day": WorldClock.day})
	for enemy: HostileCreature in mine.get_generated_enemies():
		if enemy != guardians[0]:
			enemy.load_state_data({"health": 0, "defeated": true, "defeated_day": WorldClock.day})
	mine.call("_refresh_ladder")
	assert_false((mine.get_node("DeepLadder") as MineLadder).unlocked, "the guardian still stands")
	guardians[0].load_state_data({"health": 0, "defeated": true, "defeated_day": WorldClock.day})
	mine.call("_refresh_ladder")
	assert_true((mine.get_node("DeepLadder") as MineLadder).unlocked)
	assert_null(mine.get_standing_guardian())

func test_a_guarded_floor_holds_a_royal_hoard_sealed_until_its_guardian_falls_and_found_once() -> void:
	var inventory := InventoryState.to_save_data()
	var wallet := Wallet.to_save_data()
	InventoryState.clear()
	MineState.set_floor(25)
	var mine := (load("res://game/world/old_mine.tscn") as PackedScene).instantiate() as MineFloorController
	add_child_autofree(mine)
	await get_tree().process_frame
	await get_tree().process_frame
	var chests := mine.get_generated_chests()
	assert_eq(chests.size(), 1)
	var hoard := chests[0]
	assert_eq(hoard.display_name, "Royal Hoard")
	assert_eq(hoard.persistent_id, &"mine_f025_chest")
	assert_lt(hoard.get_index(), mine.get_node("Player").get_index(), "under the player")
	assert_true(hoard.locked, "sealed while the Slime King stands")
	mine.get_generated_guardians()[0].load_state_data({"health": 0, "defeated": true, "defeated_day": WorldClock.day})
	mine.call("_refresh_ladder")
	assert_false(hoard.locked, "open once it falls")
	var money := Wallet.money
	var taken := hoard.open()
	assert_gte(taken.money, 300 + 5 * 24, "a hoard of the twenty-fifth floor")
	assert_eq(Wallet.money, money + taken.money)
	assert_true(hoard.is_emptied())
	var again := (load("res://game/world/old_mine.tscn") as PackedScene).instantiate() as MineFloorController
	add_child_autofree(again)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(again.get_generated_chests()[0].is_emptied(), "found once in a world")
	assert_true(ItemSources.describe(&"gold_ore").has(tr("Found in chests in the mine")), "a way to get what it held")
	var with_chest := 0
	for floor: int in range(2, 121):
		if not MineState.generate_floor_layout(floor)["chests"].is_empty():
			with_chest += 1
	assert_between(with_chest, 20, 40, "about one floor in five holds one")
	InventoryState.load_save_data(inventory)
	Wallet.load_save_data(wallet)

func test_every_mine_enemy_looks_like_no_other() -> void:
	var looks: Dictionary[String, StringName] = {}
	var fallbacks: Dictionary[Color, StringName] = {}
	for enemy: EnemyData in EnemyData.find_all():
		var look := "%s %s" % [enemy.sprite_path, enemy.sprite_tint]
		assert_false(looks.has(look), "%s shares its look with %s" % [enemy.id, looks.get(look, &"")])
		assert_false(fallbacks.has(enemy.fallback_color), "%s shares its fallback colour with %s" % [enemy.id, fallbacks.get(enemy.fallback_color, &"")])
		looks[look] = enemy.id
		fallbacks[enemy.fallback_color] = enemy.id

func test_the_elevator_names_the_guardian_that_holds_a_stop() -> void:
	MineState.set_floor(26)
	MineState.set_floor(1)
	var elevator := (load("res://tiamat/modules/lifesim/mining/mine_elevator.tscn") as PackedScene).instantiate() as MineElevator
	add_child_autofree(elevator)
	elevator.interactable.interacted.emit(null)
	var menu := elevator.get_choice_menu()
	assert_eq(menu.get_note(&"25"), "Guarded by Slime King")
	assert_eq(menu.get_note(&"20"), "")
	menu.close()
	WorldState.set_value(HostileCreature.state_key_of(MineRunState.guardian_persistent_id(25, 0)), {"health": 0, "defeated": true, "defeated_day": WorldClock.day})
	elevator.interactable.interacted.emit(null)
	assert_eq(menu.get_note(&"25"), "", "felled this week, it holds the stop no more")
	menu.close()
	InputLock.clear()

func test_deeper_floors_hold_elite_slimes_the_scene_spawns_in_their_form() -> void:
	var odds := MineState.floor_table.elite_odds
	assert_eq(odds.get_chance(9), 0.0, "none above floor 10")
	assert_almost_eq(odds.get_chance(62), 0.25, 0.005, "one in four from floor 62")
	var elite_floor := 0
	for floor: int in range(62, 120):
		for entry: Dictionary in MineState.generate_floor_layout(floor)["enemies"]:
			if not String(entry["elite"]).is_empty():
				assert_false(entry.has("guardian"), "a guardian is no elite")
				elite_floor = floor if elite_floor == 0 else elite_floor
	assert_gt(elite_floor, 0, "some floor holds an elite")
	MineState.set_floor(elite_floor)
	var mine := (load("res://game/world/old_mine.tscn") as PackedScene).instantiate() as MineFloorController
	add_child_autofree(mine)
	await get_tree().process_frame
	await get_tree().process_frame
	var elites := mine.get_generated_enemies().filter(func(enemy: HostileCreature) -> bool: return enemy.elite != null)
	assert_gt(elites.size(), 0)
	var elite: HostileCreature = elites[0]
	assert_eq(elite.get_display_name(), elite.elite.name_of(elite.data))
	assert_gt(elite.get_max_health(), HostileCreature.max_health_of(elite.data))
