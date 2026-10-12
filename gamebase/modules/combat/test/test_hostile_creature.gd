extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const HOSTILE_CREATURE_SCENE := preload("res://gamebase/modules/combat/combat/hostile_creature.tscn")

var _clock_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _vitals_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _world_snapshot: Dictionary
var _reduced_motion := false

func before_each() -> void:
	_reduced_motion = GameSettings.reduced_motion
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

func test_loaded_enemy_state_clamps_future_respawn_markers() -> void:
	WorldClock.set_time(10, 8 * 60)
	var enemy := _add_slime(&"")
	enemy.load_state_data({"health": 999, "defeated": true, "defeated_day": 999999, "pending_drop_quantity": 999999}, false)
	assert_true(enemy.is_defeated)
	assert_eq(enemy.defeated_day, 10)
	assert_eq(enemy.health.current, 0)
	assert_eq(enemy.pending_drop_quantity, 999999)
	assert_eq(enemy.collision_layer, 0, "a creature loaded as defeated blocks nothing")
	assert_false(enemy.is_physics_processing())
	enemy.load_state_data({"health": 0, "defeated": false, "defeated_day": 999999, "pending_drop_quantity": -10}, false)
	assert_false(enemy.is_defeated)
	assert_eq(enemy.defeated_day, 0)
	assert_eq(enemy.health.current, enemy.data.max_health)
	assert_eq(enemy.pending_drop_quantity, 0)
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
	assert_signal_emitted_with_parameters(CombatEvents, "enemy_defeated", [&"fixture_slime", 20])

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

func test_a_hit_stuns_the_creature_for_a_moment() -> void:
	var slime := _add_slime(&"")
	slime.global_position = Vector2(-5000, -5000)
	watch_signals(CombatEvents)
	assert_false(slime.hurtbox.receive(Damage.new(12, FactionData.MONSTERS)), "its own side")
	assert_true(slime.hurtbox.receive(Damage.new(12, FactionData.PLAYER, null, Vector2(100, 0))))
	assert_eq(slime.health.current, 18)
	assert_eq(slime.get_state(), HostileCreature.STATE_HURT)
	assert_signal_emitted_with_parameters(CombatEvents, "enemy_hurt", [&"fixture_slime", 12])
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

func test_enemy_ground_drops_do_not_count_as_forage() -> void:
	var slime := _add_slime(&"")
	var gel := ItemData.find(&"fixture_gel")
	var enemy_drop := slime.call("_make_drop_pickup", gel, 1) as WorldItemPickup
	assert_not_null(enemy_drop)
	if enemy_drop != null:
		assert_false(enemy_drop.counts_as_forage)
		enemy_drop.free()

func test_pending_ground_loot_is_saved_with_the_creature() -> void:
	var enemy := _add_slime(&"fixture_pending_slime")
	await get_tree().process_frame
	enemy.load_state_data({
		"health": 0,
		"defeated": true,
		"defeated_day": WorldClock.day,
		"pending_drop_quantity": 3,
	})
	assert_eq(enemy.pending_drop_quantity, 3)
	var enemy_saved := WorldState.get_value(&"enemy:fixture_pending_slime", {}) as Dictionary
	assert_eq(int(enemy_saved.get("pending_drop_quantity", 0)), 3)

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
