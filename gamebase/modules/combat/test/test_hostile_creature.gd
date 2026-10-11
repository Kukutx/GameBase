extends GutTest

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")
const HOSTILE_CREATURE_SCENE := preload("res://gamebase/modules/combat/combat/hostile_creature.tscn")

var _clock_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _player_snapshot: Dictionary
var _hotbar_snapshot: Dictionary
var _world_snapshot: Dictionary

func before_each() -> void:
	_clock_snapshot = WorldClock.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_player_snapshot = PlayerState.to_save_data()
	_hotbar_snapshot = Hotbar.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	ContentFixture.use(self, _fixture_content())
	InventoryState.clear()
	WorldState.clear()
	PlayerState.reset_new_game()

func after_each() -> void:
	# GUT frees the fixture content only after this method: restore the
	# services with the game's content, which their snapshots name.
	ContentRegistry.active = ContentDB
	WorldClock.load_save_data(_clock_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	PlayerState.load_save_data(_player_snapshot)
	Hotbar.load_save_data(_hotbar_snapshot)
	WorldState.load_save_data(_world_snapshot)

func test_loaded_enemy_state_clamps_future_respawn_markers() -> void:
	WorldClock.set_time(10, 8 * 60)
	var enemy := _add_slime(&"")
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

func test_creature_takes_damage_drops_loot_and_reports_its_defeat() -> void:
	var slime := HOSTILE_CREATURE_SCENE.instantiate() as HostileCreature
	slime.data = EnemyData.find(&"fixture_slime")
	slime.persistent_id = &""
	slime.global_position = Vector2(10000, 10000)
	add_child_autofree(slime)
	watch_signals(CombatEvents)

	assert_true(slime.take_damage(15))
	assert_eq(slime.health, 15)
	assert_true(slime.take_damage(15))
	assert_true(slime.is_defeated)
	assert_eq(InventoryState.get_quantity(&"fixture_gel"), 1)
	assert_signal_emit_count(CombatEvents, "enemy_defeated", 1)
	assert_signal_emitted_with_parameters(CombatEvents, "enemy_defeated", [&"fixture_slime", 20])

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

# A slime with 30 health that drops one gel and is worth 20 combat experience.
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
	return [gel, slime]
