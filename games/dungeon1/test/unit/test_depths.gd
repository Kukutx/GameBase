extends GutTest

## Ember Depths' runs: the depth a run reaches and what it raises in the
## profile (depth 10 on Heavy damage taken, one more), the shortcuts a run
## may start at, how long a run lasts, what its report tells, how a floor
## lays out its enemies from the run's random stream, and when the way on
## opens.

const DEPTHS_SCENE := preload("res://game/world/depths.tscn")
const TEST_PROFILE := "user://test_dungeon1_depths/profile.json"

var _world: Dictionary
var _seed: Dictionary
var _inventory: Dictionary
var _hotbar: Dictionary
var _skills: Dictionary
var _player: Dictionary
var _vitals_snapshot: Dictionary
var _profile_path: String
var _profile: Dictionary
var _options: GameOptions

func before_each() -> void:
	_world = WorldState.to_save_data()
	_seed = GameRandom.to_save_data()
	_inventory = InventoryState.to_save_data()
	_hotbar = Hotbar.to_save_data()
	_skills = Skills.to_save_data()
	_player = Wallet.to_save_data()
	_vitals_snapshot = Vitals.to_save_data()
	_profile_path = GameProfile.profile_path
	_profile = GameProfile.to_save_data()
	_options = GameSettings.options
	GameSettings.options = GameOptions.of_running_game()
	GameProfile.profile_path = TEST_PROFILE
	GameProfile.load_save_data({})
	WorldState.clear()
	GameRandom.set_seed(4242)

func after_each() -> void:
	WorldState.load_save_data(_world)
	GameRandom.load_save_data(_seed)
	InventoryState.load_save_data(_inventory)
	Hotbar.load_save_data(_hotbar)
	Skills.load_save_data(_skills)
	Wallet.load_save_data(_player)
	Vitals.load_save_data(_vitals_snapshot)
	GameProfile.load_save_data(_profile)
	GameProfile.profile_path = _profile_path
	GameSettings.options = _options
	for path: String in [TEST_PROFILE, TEST_PROFILE + ".tmp"]:
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func test_a_run_goes_down_one_depth_at_a_time() -> void:
	watch_signals(DepthRun)
	DepthRun.start_run()
	DepthRun.descend()
	DepthRun.descend()
	assert_eq(DepthRun.get_run(), 1)
	assert_eq(DepthRun.get_depth(), 3)
	assert_eq(DepthRun.get_deepest(), 3)
	assert_signal_emitted_with_parameters(DepthRun, "depth_reached", [3])
	DepthRun.start_run()
	assert_eq(DepthRun.get_run(), 2)
	assert_eq(DepthRun.get_depth(), 1, "a new run starts at the first depth")
	assert_eq(DepthRun.get_deepest(), 3, "the world keeps its deepest depth")
	assert_eq(GameProfile.get_int(DepthRunService.PROFILE_DEEPEST), 3, "the profile keeps the deepest depth of any save")

func test_a_run_lasts_from_the_entrance_to_camp_and_blocks_saving() -> void:
	DepthRun.start_run()
	assert_true(RunState.is_active())
	assert_eq(RunState.get_save_block_reason(), "Return to camp to save")
	watch_signals(RunState)
	DepthRun.return_to_camp()
	assert_false(RunState.is_active())
	assert_signal_emitted_with_parameters(RunState, "run_ended", [1, RunService.OUTCOME_RETURNED])
	assert_eq(RunState.get_save_block_reason(), "", "the game saves at camp")

func test_without_a_run_the_way_leads_no_deeper() -> void:
	# A defeat whose way home failed leaves the player on a floor with no run.
	assert_false(DepthRun.descend())
	assert_eq(DepthRun.get_depth(), 1)
	assert_eq(DepthRun.get_deepest(), 0)
	DepthRun.start_run()
	assert_true(DepthRun.descend())
	assert_eq(DepthRun.get_depth(), 2)

func test_a_hand_edited_run_reads_as_a_run_that_has_not_started() -> void:
	WorldState.load_save_data({"depths:depth": -4.0, "depths:deepest": -9.0, "run:count": 2.5})
	assert_eq(DepthRun.get_depth(), 1)
	assert_eq(DepthRun.get_deepest(), 0)
	assert_eq(DepthRun.get_run(), 0)

func test_reaching_depth_five_and_ten_unlocks_the_achievements() -> void:
	DepthRun.start_run()
	for _step: int in 4:
		DepthRun.descend()
	assert_true(GameProfile.is_unlocked(&"delver"))
	assert_false(GameProfile.is_unlocked(&"ember_heart"))
	for _step: int in 5:
		DepthRun.descend()
	assert_true(GameProfile.is_unlocked(&"ember_heart"))
	assert_false(GameProfile.is_unlocked(&"forged_in_fire"), "not on standard damage taken")

func test_reaching_depth_ten_on_heavy_damage_taken_forges_one_more() -> void:
	GameSettings.options.set_value(PlayerHurtbox.DAMAGE_TAKEN_OPTION, "Heavy")
	DepthRun.start_run()
	for _step: int in 8:
		DepthRun.descend()
	assert_false(GameProfile.is_unlocked(&"forged_in_fire"), "depth 9")
	DepthRun.descend()
	assert_true(GameProfile.is_unlocked(&"forged_in_fire"))

func test_every_fifth_depth_reached_is_a_shortcut_a_run_may_start_at() -> void:
	DepthRun.start_run()
	assert_eq(DepthRun.get_shortcuts(), PackedInt32Array([1]))
	for _step: int in 11:
		DepthRun.descend()
	assert_eq(DepthRun.get_shortcuts(), PackedInt32Array([1, 5, 10]))
	watch_signals(DepthRun)
	DepthRun.start_run(10)
	assert_eq(DepthRun.get_depth(), 10)
	assert_eq(DepthRun.get_run(), 2)
	assert_eq(RunState.get_tally(DepthRunService.DEPTH_TALLY), 10, "the run's report tells the depth it started at")
	assert_signal_not_emitted(DepthRun, "depth_reached", "a run that starts at a shortcut does not reach it again")
	DepthRun.descend()
	assert_signal_emitted_with_parameters(DepthRun, "depth_reached", [11])
	DepthRun.start_run(15)
	assert_eq(DepthRun.get_depth(), 1, "a depth the world has not reached starts at the first")
	DepthRun.start_run(7)
	assert_eq(DepthRun.get_depth(), 1, "and so does a depth that is no shortcut")

func test_the_way_down_asks_where_to_start_once_the_world_has_a_shortcut() -> void:
	var entrance := DepthEntrance.new()
	var interactable := Interactable.new()
	interactable.name = "Interactable"
	entrance.add_child(interactable)
	add_child_autofree(entrance)
	DepthRun.start_run()
	assert_eq(await entrance.choose_start(), 1, "without a shortcut the run starts at the top")
	assert_null(ChoiceMenu.of(entrance))
	for _step: int in 5:
		DepthRun.descend()
	var outcome := {}
	(func() -> void: outcome["depth"] = await entrance.choose_start()).call()
	var menu := ChoiceMenu.of(entrance)
	assert_eq(menu.get_buttons().map(func(button: Button) -> String: return button.text), ["Depth 1", "Depth 5"])
	assert_eq(menu.get_note(&"5"), "Skips the first 4 depths")
	assert_true(menu.get_button(&"5").has_focus(), "the deepest shortcut first")
	menu.choose(&"5")
	assert_eq(outcome.get("depth"), 5)
	(func() -> void: outcome["depth"] = await entrance.choose_start()).call()
	menu.close()
	assert_eq(outcome.get("depth"), 0, "closing the list starts no run")
	InputLock.clear()

func test_after_the_first_run_the_way_down_offers_pacts() -> void:
	var entrance := DepthEntrance.new()
	var interactable := Interactable.new()
	interactable.name = "Interactable"
	entrance.add_child(interactable)
	add_child_autofree(entrance)
	assert_eq(await entrance.choose_pact(), DepthEntrance.NO_PACT, "the first run starts under none")
	assert_null(ChoiceMenu.of(entrance))
	DepthRun.start_run()
	DepthRun.return_to_camp()
	var outcome := {}
	(func() -> void: outcome["pact"] = await entrance.choose_pact()).call()
	var menu := ChoiceMenu.of(entrance)
	assert_eq(menu.get_choice_ids(), [DepthEntrance.NO_PACT, &"pact_of_ash", &"pact_of_glass"] as Array[StringName], "Greed waits for the Delver")
	assert_true(menu.get_button(DepthEntrance.NO_PACT).has_focus())
	menu.choose(&"pact_of_glass")
	assert_eq(outcome.get("pact"), &"pact_of_glass")
	entrance.begin_run(1, outcome.get("pact"))
	assert_eq(RunState.get_boon_stacks(&"pact_of_glass"), 1, "the run starts under it")
	assert_almost_eq(GameStats.get_multiplier(&"attack_damage"), 1.5, 0.001)
	assert_eq(Vitals.get_maximum(&"hp"), 60)
	assert_false(RunState.offer_boons(10, "altar").any(func(boon: BoonData) -> bool: return boon.pool == DepthEntrance.PACT_POOL), "an altar offers no pact")
	for _depth: int in 9:
		DepthRun.descend()
	assert_true(GameProfile.is_unlocked(&"unbroken_glass"))
	InputLock.clear()

func test_a_deeper_floor_spawns_more_enemies() -> void:
	assert_eq(DepthFloor.get_enemy_count(1), 2)
	assert_eq(DepthFloor.get_enemy_count(2), 3)
	assert_eq(DepthFloor.get_enemy_count(4), 4)
	assert_eq(DepthFloor.get_enemy_count(40), 8, "a floor holds at most eight")
	assert_eq(DepthFloor.get_enemy_count(10, true), 3, "half as many where a guardian stands")

func test_every_fifth_depth_an_ember_warden_guards_the_way_on() -> void:
	DepthRun.start_run()
	DepthRun.track.set_depth(4)
	assert_eq(_enter_floor().get_guardians(), [] as Array[HostileCreature], "the fourth depth has no guardian")
	DepthRun.track.set_depth(5)
	watch_signals(GameEvents)
	var depth_floor := _enter_floor()
	var guardians := depth_floor.get_guardians()
	assert_eq(guardians.size(), 1)
	assert_eq(guardians[0].data.id, &"ember_warden")
	assert_eq(depth_floor.get_enemies().size(), 3, "the warden and half the fifth depth's four creatures")
	assert_signal_emitted_with_parameters(GameEvents, "toast_requested", ["Ember Warden guards this depth"])
	assert_string_contains((depth_floor.get_node("DepthLabel") as Label).text, "Ember Warden guards this depth")
	assert_eq(depth_floor.get_place_detail(), "Depth 5", "the HUD tells the depth")
	var arrival := depth_floor.get_node("ArrivalSpawn") as Node2D
	for enemy: HostileCreature in depth_floor.get_enemies():
		assert_true(guardians[0].position.distance_to(arrival.position) >= enemy.position.distance_to(arrival.position) - 0.01,
			"the warden stands furthest from the way in")
	for enemy: HostileCreature in depth_floor.get_enemies():
		if enemy != guardians[0]:
			enemy.take_damage(enemy.get_max_health())
	await get_tree().process_frame
	assert_false(depth_floor.is_cleared(), "the way on stays shut while the warden stands")
	guardians[0].take_damage(guardians[0].get_max_health())
	await get_tree().process_frame
	assert_true(depth_floor.is_cleared())
	assert_true(GameProfile.is_unlocked(&"warden_felled"))
	assert_eq(InventoryState.get_quantity(&"ember_core"), 2, "the warden drops two ember cores")
	assert_false((depth_floor.get_node("DepthLabel") as Label).text.contains("guards"), "a fallen warden guards nothing")
	DepthRun.track.set_depth(10)
	assert_eq(_enter_floor().get_guardians().size(), 1, "and again at the tenth")

func test_the_same_run_and_depth_lay_out_the_same_floor() -> void:
	DepthRun.start_run()
	var first := _layout(_enter_floor())
	assert_eq(first.size(), 2)
	assert_eq(_layout(_enter_floor()), first, "entering the floor again lays it out the same")
	DepthRun.start_run()
	assert_ne(_layout(_enter_floor()), first, "another run lays out its own floor")

func test_a_floor_spawns_only_the_tiers_its_depth_reaches() -> void:
	DepthRun.start_run()
	for enemy: HostileCreature in _enter_floor().get_enemies():
		assert_eq(enemy.data.id, &"cave_slime", "the first depth holds only slimes")
	var tiers := _enter_floor().enemy_tiers
	assert_eq(EnemyTier.reached(tiers, 2), [&"cave_slime"])
	assert_eq(EnemyTier.reached(tiers, 3), [&"cave_slime", &"skeleton"], "skeletons from the third depth")
	assert_eq(EnemyTier.reached(tiers, 5), [&"cave_slime", &"skeleton"], "no wisps before the sixth")
	assert_eq(EnemyTier.reached(tiers, 6), [&"cave_slime", &"skeleton", &"ember_wisp"])
	DepthRun.track.set_depth(5)
	for enemy: HostileCreature in _enter_floor().get_enemies():
		assert_ne(enemy.data.id, &"ember_wisp", "the fifth depth holds no wisps")

func test_the_way_on_opens_once_every_enemy_is_defeated() -> void:
	DepthRun.start_run()
	var depth_floor := _enter_floor()
	var stairs := depth_floor.get_node("Stairs/Interactable") as Interactable
	var rope := depth_floor.get_node("Rope/Interactable") as Interactable
	assert_false(depth_floor.is_cleared())
	assert_false(stairs.enabled)
	assert_false(rope.enabled)
	for enemy: HostileCreature in depth_floor.get_enemies():
		enemy.take_damage(enemy.get_max_health())
	await get_tree().process_frame
	assert_true(depth_floor.is_cleared())
	assert_true(stairs.enabled and depth_floor.get_node("Stairs").visible)
	assert_true(rope.enabled and depth_floor.get_node("Rope").visible)
	assert_string_contains((depth_floor.get_node("DepthLabel") as Label).text, "The way on is open")
	assert_eq(InventoryState.get_quantity(&"slime_gel"), 2, "each slime dropped its gel")
	assert_true(GameProfile.is_unlocked(&"first_blood"))
	assert_eq(Skills.get_xp(&"combat"), 2 * EnemyData.find(&"cave_slime").combat_xp)
	assert_eq(GameProfile.get_progress(&"slayer"), 2, "every creature counts toward Slayer")

func test_creatures_defeated_in_every_run_count_toward_slayer() -> void:
	# As if earlier runs had defeated 99.
	GameProfile.set_flag(&"creatures_defeated", 99)
	assert_false(GameProfile.is_unlocked(&"slayer"))
	GameTriggers.fire(&"CombatEvents.enemy_defeated", {"enemy_id": &"cave_slime", "combat_xp": 1, "position": Vector2.ZERO})
	assert_true(GameProfile.is_unlocked(&"slayer"))

func test_a_run_tells_the_depth_it_reached_and_the_creatures_it_defeated() -> void:
	assert_eq(RunTallyData.find(DepthRunService.DEPTH_TALLY).best_flag, DepthRunService.PROFILE_DEEPEST, "the depth tally keeps the profile's deepest depth")
	DepthRun.start_run()
	DepthRun.descend()
	for _enemy: int in 3:
		GameTriggers.fire(&"CombatEvents.enemy_defeated", {"enemy_id": &"cave_slime", "combat_xp": 1, "position": Vector2.ZERO})
	DepthRun.return_to_camp()
	assert_eq(RunState.get_last_report().lines, PackedStringArray(["Depth Reached: 2", "Creatures Defeated: 3"]))
	assert_eq(GameProfile.get_int(&"most_creatures_in_a_run"), 3)
	DepthRun.start_run()
	for _enemy: int in 4:
		GameTriggers.fire(&"CombatEvents.enemy_defeated", {"enemy_id": &"cave_slime", "combat_xp": 1, "position": Vector2.ZERO})
	DepthRun.return_to_camp()
	assert_eq(RunState.get_last_report().lines, PackedStringArray(["Depth Reached: 1", "Creatures Defeated: 4 · New best"]))
	assert_eq(GameProfile.get_progress(&"ember_rampage"), 4, "the best run counts toward Ember Rampage")
	GameProfile.set_flag(&"most_creatures_in_a_run", 15)
	assert_true(GameProfile.is_unlocked(&"ember_rampage"))

func test_what_the_player_gets_goes_to_the_hotbar() -> void:
	InventoryState.clear()
	Hotbar.load_save_data({})
	InventoryState.add_item_by_id(&"bone_shard")
	assert_true(Hotbar.slots.has(&"bone_shard"))

func test_a_potion_is_drunk_only_when_it_heals() -> void:
	InventoryState.clear()
	InventoryState.add_item_by_id(&"health_potion", 2)
	Vitals.refill(&"hp")
	var player := DelverPlayer.new()
	assert_false(player.drink_potion(), "a player at full health needs no potion")
	Vitals.drain(&"hp", 40)
	watch_signals(GameEvents)
	assert_true(player.drink_potion())
	assert_signal_emitted_with_parameters(GameEvents, "toast_requested", ["Drank Health Potion (+35 Health)"])
	assert_eq(InventoryState.get_quantity(&"health_potion"), 1)
	assert_eq(Vitals.get_value(&"hp"), Vitals.get_maximum(&"hp") - 5)
	InventoryState.clear()
	assert_false(player.drink_potion(), "no potion, no drink")
	player.free()

func test_a_cleared_floor_lights_its_ember_altar_for_one_boon() -> void:
	DepthRun.start_run()
	var depth_floor := _enter_floor()
	assert_false(depth_floor.altar.visible or depth_floor.altar.interactable.enabled, "dark until the floor is cleared")
	assert_eq(depth_floor.altar.get_key(), "depth1")
	for enemy: HostileCreature in depth_floor.get_enemies():
		enemy.take_damage(enemy.get_max_health())
	await get_tree().process_frame
	assert_true(depth_floor.altar.visible and depth_floor.altar.interactable.enabled)
	var outcome := {}
	(func() -> void: outcome["boon"] = await depth_floor.altar.choose()).call()
	var menu := ChoiceMenu.of(depth_floor.altar)
	assert_eq(menu.get_buttons().size(), 3, "three of the depths' boons")
	var offered := menu.get_choice_ids()[0]
	assert_true(menu.choose(offered))
	assert_eq(outcome.get("boon"), offered)
	assert_eq(RunState.get_boon_stacks(offered), 1)
	assert_false(depth_floor.altar.visible, "spent")
	assert_false(_enter_floor().altar.visible, "the same depth of the same run lights it no more")

func test_five_boons_in_one_run_bless_the_delver() -> void:
	DepthRun.start_run()
	for boon_id: StringName in [&"ember_edge", &"ember_edge", &"fleet_foot", &"ember_skin"]:
		assert_true(RunState.take_boon(boon_id), String(boon_id))
	assert_false(GameProfile.is_unlocked(&"ember_blessed"))
	assert_true(RunState.take_boon(&"second_wind"))
	assert_true(GameProfile.is_unlocked(&"ember_blessed"))
	assert_almost_eq(RunState.get_stat_multiplier(&"attack_damage"), 1.5625, 0.001, "two Ember Edges")
	assert_almost_eq(RunState.get_stat_multiplier(PlayerHurtbox.INCOMING_DAMAGE_STAT), 0.8, 0.001)

func test_the_embers_remember_what_the_delver_achieved() -> void:
	DepthRun.start_run()
	var heart := BoonData.find(&"heart_of_embers")
	assert_false(heart.can_take(), "not before Ember Heart")
	assert_false(RunState.offer_boons(9, "all").has(heart))
	GameProfile.unlock(&"ember_heart")
	assert_true(heart.can_take())
	assert_true(RunState.offer_boons(9, "all").has(heart))

func _enter_floor() -> DepthFloor:
	var depth_floor := DEPTHS_SCENE.instantiate() as DepthFloor
	add_child_autofree(depth_floor)
	return depth_floor

# Each enemy's kind and position, in spawn order.
func _layout(depth_floor: DepthFloor) -> Array:
	var layout := []
	for enemy: HostileCreature in depth_floor.get_enemies():
		layout.append([enemy.data.id, enemy.position])
	return layout
