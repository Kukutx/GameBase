extends GutTest

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")
const HOSTILE_CREATURE_SCENE := preload("res://tiamat/modules/combat/combat/hostile_creature.tscn")

var _clock_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _vitals_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _world_snapshot: Dictionary
var _reduced_motion := false
var _options: GameOptions

func before_each() -> void:
	_reduced_motion = GameSettings.reduced_motion
	_options = GameSettings.options
	_clock_snapshot = WorldClock.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_vitals_snapshot = Vitals.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	ContentFixture.use(self, _fixture_content())
	var settings := CombatSettings.new()
	settings.health_vital_id = &"fixture_hp"
	ContentFixture.use_settings(self, [settings])
	InventoryState.clear()
	WorldState.clear()
	Vitals.reset_new_game()

func after_each() -> void:
	# GUT frees the fixture content only after this method: restore the
	# services with the game's content, which their snapshots name.
	ContentRegistry.active = ContentDB
	WorldClock.load_save_data(_clock_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	Vitals.load_save_data(_vitals_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	WorldState.load_save_data(_world_snapshot)
	GameSettings.reduced_motion = _reduced_motion
	GameSettings.options = _options
	# The creatures the test left go after this hook; their fight goes now.
	FightState.end_fight()

func test_loaded_enemy_state_clamps_future_respawn_markers() -> void:
	WorldClock.set_time(10, 8 * 60)
	var enemy := _add_slime(&"")
	enemy.load_state_data({"health": 999, "defeated": true, "defeated_day": 999999, "pending_drop_quantity": 999999}, false)
	assert_true(enemy.is_defeated)
	assert_eq(enemy.defeated_day, 10)
	assert_eq(enemy.health.current, 0)
	assert_eq(enemy.drop.quantity, 999999)
	assert_eq(enemy.collision_layer, 0, "a creature loaded as defeated blocks nothing")
	assert_false(enemy.is_physics_processing())
	enemy.load_state_data({"health": 0, "defeated": false, "defeated_day": 999999, "pending_drop_quantity": -10}, false)
	assert_false(enemy.is_defeated)
	assert_eq(enemy.defeated_day, 0)
	assert_eq(enemy.health.current, enemy.data.max_health)
	assert_eq(enemy.drop.quantity, 0)
	assert_ne(enemy.collision_layer, 0, "and one loaded alive does")
	assert_true(enemy.is_physics_processing())

func test_creature_takes_damage_drops_loot_and_reports_its_defeat() -> void:
	var slime := HOSTILE_CREATURE_SCENE.instantiate() as HostileCreature
	slime.data = EnemyData.find(&"fixture_slime")
	slime.persistent_id = &""
	slime.global_position = Vector2(10000, 10000)
	add_child_autofree(slime)
	watch_signals(CombatEvents)

	assert_true(slime.take_damage(15))
	assert_eq(slime.health.current, 15)
	assert_true(slime.take_damage(15))
	assert_true(slime.is_defeated)
	assert_eq(InventoryState.get_quantity(&"fixture_gel"), 1)
	assert_signal_emit_count(CombatEvents, "enemy_defeated", 1)
	assert_signal_emitted_with_parameters(CombatEvents, "enemy_defeated", [&"fixture_slime", 20, Vector2(10000, 10000)])

func test_the_loot_stat_changes_what_a_creature_drops() -> void:
	var slime := HOSTILE_CREATURE_SCENE.instantiate() as HostileCreature
	slime.data = EnemyData.find(&"fixture_slime")
	slime.persistent_id = &""
	add_child_autofree(slime)
	assert_eq(slime.get_drop_quantity(), 1)
	var loot := _Loot.new()
	GameStats.register_source(loot)
	loot.multiplier = 3.0
	assert_eq(slime.get_drop_quantity(), 3)
	loot.multiplier = 1.5
	assert_between(slime.get_drop_quantity(), 1, 2, "half a gel more, by chance")
	loot.multiplier = 0.0001
	assert_eq(slime.get_drop_quantity(), 0, "next to nothing drops nothing")
	assert_true(slime.take_damage(30))
	assert_eq(InventoryState.get_quantity(&"fixture_gel"), 0)
	GameStats.unregister_source(loot)

func test_a_creature_chases_and_strikes_the_player_s_hurtbox() -> void:
	GameSettings.reduced_motion = true
	var player := CharacterBody2D.new()
	player.add_to_group(&"player")
	var target := PlayerHurtbox.new()
	player.add_child(target)
	player.global_position = Vector2(5000, 5000)
	add_child_autofree(player)
	var slime := _add_slime(&"")
	slime.global_position = player.global_position + Vector2(10, 0)
	watch_signals(CombatEvents)
	for frame in range(10):
		if not Vitals.is_full(&"fixture_hp"):
			break
		await get_tree().physics_frame
	assert_eq(slime.get_state(), HostileCreature.STATE_CHASE)
	assert_eq(Vitals.get_value(&"fixture_hp"), 100 - slime.data.contact_damage)
	assert_signal_emit_count(CombatEvents, "player_hurt", 1)
	assert_true(target.is_invincible(), "the next strike waits for the player's moment")
	assert_eq(FightState.get_hunter_count(), 1, "a creature that chases the player hunts them")
	slime.free()
	assert_eq(FightState.get_hunter_count(), 0, "one that leaves hunts no more")

func test_a_creature_that_winds_up_strikes_only_if_the_player_stays_in_reach() -> void:
	var player := CharacterBody2D.new()
	player.add_to_group(&"player")
	player.add_child(PlayerHurtbox.new())
	player.global_position = Vector2(5000, 5000)
	add_child_autofree(player)
	var slime := _add_slime(&"")
	slime.data.windup_seconds = 0.3
	slime.global_position = player.global_position + Vector2(10, 0)
	assert_true(await wait_until(func() -> bool: return slime.get_state() == HostileCreature.STATE_WINDUP, 1.0), "the player in reach")
	assert_eq(slime.visual.modulate, slime.windup_color, "it glows")
	assert_true(Vitals.is_full(&"fixture_hp"), "nothing lands yet")
	player.global_position += Vector2(slime.data.attack_range * 2.0, 0)
	assert_true(await wait_until(func() -> bool: return slime.get_state() != HostileCreature.STATE_WINDUP, 1.0))
	assert_true(Vitals.is_full(&"fixture_hp"), "a step out of reach dodges it")
	assert_eq(slime.visual.modulate, Color.WHITE)
	slime.global_position = player.global_position + Vector2(10, 0)
	assert_true(await wait_until(func() -> bool: return slime.get_state() == HostileCreature.STATE_WINDUP, 3.0), "again once its cooldown is over")
	assert_true(slime.hurtbox.receive(Damage.new(1, FactionData.PLAYER)))
	assert_eq(slime.get_state(), HostileCreature.STATE_HURT, "a hit stuns it out of its windup")
	assert_eq(slime.visual.modulate, Color.WHITE)
	assert_true(await wait_until(func() -> bool: return not Vitals.is_full(&"fixture_hp"), 3.0), "one that stays in reach is struck")
	assert_eq(Vitals.get_value(&"fixture_hp"), 100 - slime.data.contact_damage)

func test_a_hit_stuns_the_creature_for_a_moment() -> void:
	var slime := _add_slime(&"")
	slime.global_position = Vector2(-5000, -5000)
	watch_signals(CombatEvents)
	assert_false(slime.hurtbox.receive(Damage.new(12, FactionData.MONSTERS)), "its own side")
	assert_true(slime.hurtbox.receive(Damage.new(12, FactionData.PLAYER, null, Vector2(100, 0))))
	assert_eq(slime.health.current, 18)
	assert_eq(slime.get_state(), HostileCreature.STATE_HURT)
	assert_signal_emitted_with_parameters(CombatEvents, "enemy_hurt", [&"fixture_slime", 12, Vector2(-5000, -5000)])
	await wait_until(func() -> bool: return not slime.hurtbox.is_invincible(), 1.0)
	assert_true(slime.hurtbox.receive(Damage.new(1, FactionData.PLAYER)), "the next hit after its invincibility")
	await wait_seconds(HostileCreature.HURT_SECONDS * 0.75)
	assert_eq(slime.get_state(), HostileCreature.STATE_HURT, "each hit stuns it from that hit")
	await wait_seconds(HostileCreature.HURT_SECONDS * 0.5)
	assert_ne(slime.get_state(), HostileCreature.STATE_HURT)
	assert_true(slime.take_damage(17))
	assert_eq(slime.get_state(), HostileCreature.STATE_DEFEATED)
	assert_false(slime.hurtbox.enabled, "nothing hits a defeated creature")

func test_a_defeated_creature_rests_until_it_comes_back() -> void:
	WorldClock.set_time(3, 8 * 60)
	var slime := _add_slime(&"")
	slime.global_position = Vector2(10000, 10000)
	assert_true(slime.is_physics_processing())
	assert_true(slime.take_damage(30))
	# Its death plays out, then nothing of it runs.
	for frame in range(120):
		if not slime.is_physics_processing():
			break
		await get_tree().physics_frame
	assert_false(slime.is_physics_processing())
	WorldClock.set_time(4, 8 * 60)
	assert_false(slime.is_defeated)
	assert_true(slime.is_physics_processing())

func test_a_creature_that_came_back_while_away_loads_alive() -> void:
	WorldClock.set_time(5, 8 * 60)
	WorldState.set_value(&"enemy:fixture_back_slime", {"health": 0, "defeated": true, "defeated_day": 4})
	var slime := _add_slime(&"fixture_back_slime")
	assert_false(slime.is_defeated)
	assert_eq(slime.health.current, slime.data.max_health)
	assert_ne(slime.collision_layer, 0, "it blocks again")
	assert_true(slime.hurtbox.enabled, "and can be hit")
	assert_true(slime.is_physics_processing(), "and moves")
	assert_true(slime.fallback.visible or slime.visual.visible)

func test_the_killing_blow_pushes_nothing() -> void:
	var slime := _add_slime(&"")
	slime.global_position = Vector2(-8000, 8000)
	assert_true(slime.hurtbox.receive(Damage.new(30, FactionData.PLAYER, null, Vector2(400, 0))))
	assert_true(slime.is_defeated)
	await wait_seconds(Hurtbox.KNOCKBACK_SECONDS + 0.1)
	assert_eq(slime.global_position, Vector2(-8000, 8000), "a defeated creature stays where it fell")

func test_loot_the_bag_cannot_hold_waits_where_the_creature_fell() -> void:
	# The pile lies in the place the player is in.
	var place := Node2D.new()
	get_tree().root.add_child(place)
	autofree(place)
	var scene_before := get_tree().current_scene
	get_tree().current_scene = place
	var slots := InventoryState.max_slots
	InventoryState.max_slots = 1
	var gel := ItemData.find(&"fixture_gel")
	InventoryState.add_item(gel, gel.max_stack)
	var slime := _add_slime(&"fixture_full_bag_slime")
	slime.global_position = Vector2(300, 40)
	assert_true(slime.take_damage(30))
	assert_eq(slime.drop.quantity, 1, "the full bag left its gel")
	var saved := WorldState.get_value(&"enemy:fixture_full_bag_slime", {}) as Dictionary
	assert_eq(int(saved.get("pending_drop_quantity", 0)), 1, "and it saves with the creature")
	await get_tree().process_frame
	var piles := place.get_children().filter(func(child: Node) -> bool: return child is WorldItemPickup)
	get_tree().current_scene = scene_before
	InventoryState.max_slots = slots
	assert_eq(piles.size(), 1, "the gel lies where it fell")
	if not piles.is_empty():
		assert_eq((piles[0] as WorldItemPickup).global_position, Vector2(300, 40))
		assert_false((piles[0] as WorldItemPickup).counts_as_forage)

func test_pending_ground_loot_is_saved_with_the_creature() -> void:
	var enemy := _add_slime(&"fixture_pending_slime")
	await get_tree().process_frame
	enemy.load_state_data({
		"health": 0,
		"defeated": true,
		"defeated_day": WorldClock.day,
		"pending_drop_quantity": 3,
	})
	assert_eq(enemy.drop.quantity, 3)
	var enemy_saved := WorldState.get_value(&"enemy:fixture_pending_slime", {}) as Dictionary
	assert_eq(int(enemy_saved.get("pending_drop_quantity", 0)), 3)

func test_the_player_chooses_how_strong_the_creatures_are() -> void:
	GameSettings.options = GameOptions.new(CombatModule.new().get_options())
	assert_eq(GameSettings.get_option(HostileCreature.STRENGTH_OPTION), "Standard", "the module offers the choice, standard at first")
	GameSettings.options.set_value(HostileCreature.STRENGTH_OPTION, "Strong")
	var strong := _add_slime(&"")
	assert_eq(strong.health.maximum, 45, "half again its kind's 30")
	assert_eq(strong.health.current, 45)
	GameSettings.options.set_value(HostileCreature.STRENGTH_OPTION, "Weak")
	assert_eq(_add_slime(&"").health.maximum, 23, "three quarters of 30, rounded")
	GameSettings.options = GameOptions.new()
	assert_eq(_add_slime(&"").health.maximum, 30, "a game without the option keeps its kinds' health")

func test_an_item_tells_which_creature_drops_it() -> void:
	assert_eq(ItemSources.gather().get_ways(&"fixture_gel"), PackedStringArray(["Dropped by Slime"]))

func test_an_elite_form_makes_a_creature_stronger_larger_and_worth_more() -> void:
	var elite := _elite(&"fixture_hulking", "Hulking %s")
	elite.health_scale = 1.5
	elite.size_scale = 1.25
	elite.tint = Color(1, 0.5, 0.5)
	elite.xp_scale = 2.0
	elite.extra_drops = 2
	var plain := _add_slime(&"")
	var slime := HOSTILE_CREATURE_SCENE.instantiate() as HostileCreature
	slime.data = EnemyData.find(&"fixture_slime")
	slime.elite = elite
	slime.global_position = Vector2(10000, 10000)
	add_child_autofree(slime)
	assert_eq(slime.health.maximum, 45, "half again its kind's 30")
	assert_eq(slime.get_display_name(), "Hulking Slime")
	assert_eq(slime.health_label.text, "Hulking Slime 45/45")
	assert_eq(plain.health_label.text, "Slime 30/30")
	assert_eq(slime.visual.scale, plain.visual.scale * 1.25)
	assert_eq((slime.body_shape.shape as RectangleShape2D).size, (plain.body_shape.shape as RectangleShape2D).size * 1.25)
	assert_eq(slime.fallback.color, plain.fallback.color * Color(1, 0.5, 0.5))
	watch_signals(CombatEvents)
	slime.take_damage(45)
	assert_eq(InventoryState.get_quantity(&"fixture_gel"), 3, "its gel and two more")
	assert_signal_emitted_with_parameters(CombatEvents, "enemy_defeated", [&"fixture_slime", 40, Vector2(10000, 10000)])
	assert_signal_emitted_with_parameters(CombatEvents, "elite_defeated", [&"fixture_hulking", &"fixture_slime", Vector2(10000, 10000)])
	plain.take_damage(30)
	assert_signal_emit_count(CombatEvents, "elite_defeated", 1, "a plain creature is no elite")

func test_a_place_rolls_an_elite_whose_condition_holds_by_chance() -> void:
	var swift := _elite(&"fixture_swift", "Swift %s")
	var locked := _elite(&"fixture_locked", "Locked %s")
	locked.condition = "FALSE"
	ContentFixture.use(self, _fixture_content() + [swift, locked])
	var rolls := GameRandom.stream("fixture elites")
	var rolled := 0
	for attempt: int in 200:
		var elite := EliteData.roll(rolls, 0.5)
		if elite != null:
			rolled += 1
			assert_eq(elite.id, &"fixture_swift", "never one whose condition does not hold")
	assert_between(rolled, 60, 140, "about half")
	assert_null(EliteData.roll(rolls, 0.0))
	var unlucky := GameRandom.stream("fixture same")
	var lucky := GameRandom.stream("fixture same")
	EliteData.roll(unlucky, 0.0)
	EliteData.roll(lucky, 1.0)
	assert_eq(unlucky.randf(), lucky.randf(), "what follows does not hang on the roll")
	assert_eq(swift.find_problems(ContentRegistry.active), PackedStringArray())
	swift.display_name = "Swift"
	assert_eq(swift.find_problems(ContentRegistry.active), PackedStringArray(["display name 'Swift' needs one %s for its creature's name"]))

func _elite(id: StringName, display_name: String) -> EliteData:
	var elite := EliteData.new()
	elite.id = id
	elite.display_name = display_name
	return elite

func _add_slime(persistent_id: StringName) -> HostileCreature:
	var enemy := HOSTILE_CREATURE_SCENE.instantiate() as HostileCreature
	enemy.data = EnemyData.find(&"fixture_slime")
	enemy.persistent_id = persistent_id
	add_child_autofree(enemy)
	return enemy

# A slime with 30 health that drops one gel and is worth 20 combat
# experience, and the player's health.
func _fixture_content() -> Array:
	var gel := ItemData.new()
	gel.id = &"fixture_gel"
	gel.display_name = "Gel"
	var slime := EnemyData.new()
	slime.id = &"fixture_slime"
	slime.display_name = "Slime"
	slime.max_health = 30
	slime.drop_item_id = gel.id
	slime.drop_quantity = 1
	slime.respawn_days = 1
	slime.combat_xp = 20
	return [gel, slime, ContentFixture.vital(&"fixture_hp")]

class _Loot:
	extends RefCounted
	var multiplier := 1.0

	func get_stat_multiplier(stat: StringName) -> float:
		return multiplier if stat == PlayerHurtbox.LOOT_STAT else 1.0

	func get_stat_bonus(_stat: StringName) -> float:
		return 0.0
