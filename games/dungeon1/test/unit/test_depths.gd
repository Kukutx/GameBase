extends GutTest

## Ember Depths' runs: the depth a run reaches and what it raises in the
## profile, how long a run lasts, how a floor lays out its enemies from the
## run's random stream, and when the way on opens.

const DEPTHS_SCENE := preload("res://game/world/depths.tscn")
const TEST_PROFILE := "user://test_dungeon1_depths/profile.json"

var _world: Dictionary
var _seed: Dictionary
var _inventory: Dictionary
var _hotbar: Dictionary
var _skills: Dictionary
var _player: Dictionary
var _profile_path: String
var _profile: Dictionary

func before_each() -> void:
	_world = WorldState.to_save_data()
	_seed = GameRandom.to_save_data()
	_inventory = InventoryState.to_save_data()
	_hotbar = Hotbar.to_save_data()
	_skills = Skills.to_save_data()
	_player = PlayerState.to_save_data()
	_profile_path = GameProfile.profile_path
	_profile = GameProfile.to_save_data()
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
	PlayerState.load_save_data(_player)
	GameProfile.load_save_data(_profile)
	GameProfile.profile_path = _profile_path
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

func test_a_deeper_floor_spawns_more_enemies() -> void:
	assert_eq(DepthFloor.get_enemy_count(1), 2)
	assert_eq(DepthFloor.get_enemy_count(2), 3)
	assert_eq(DepthFloor.get_enemy_count(4), 4)
	assert_eq(DepthFloor.get_enemy_count(40), 8, "a floor holds at most eight")

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
		enemy.take_damage(enemy.data.max_health)
	await get_tree().process_frame
	assert_true(depth_floor.is_cleared())
	assert_true(stairs.enabled and depth_floor.get_node("Stairs").visible)
	assert_true(rope.enabled and depth_floor.get_node("Rope").visible)
	assert_string_contains((depth_floor.get_node("DepthLabel") as Label).text, "The way on is open")
	assert_eq(InventoryState.get_quantity(&"slime_gel"), 2, "each slime dropped its gel")
	assert_true(GameProfile.is_unlocked(&"first_blood"))
	assert_eq(Skills.get_xp(&"combat"), 2 * EnemyData.find(&"cave_slime").combat_xp)

func test_what_the_player_gets_goes_to_the_hotbar() -> void:
	InventoryState.clear()
	Hotbar.load_save_data({})
	InventoryState.add_item_by_id(&"bone_shard")
	assert_true(Hotbar.slots.has(&"bone_shard"))

func test_a_potion_is_drunk_only_when_it_heals() -> void:
	InventoryState.clear()
	InventoryState.add_item_by_id(&"health_potion", 2)
	PlayerState.restore_full_health()
	var player := DelverPlayer.new()
	assert_false(player.drink_potion(), "a player at full health needs no potion")
	PlayerState.take_damage(40)
	watch_signals(GameEvents)
	assert_true(player.drink_potion())
	assert_signal_emitted_with_parameters(GameEvents, "toast_requested", ["Drank Health Potion (+35 HP)"])
	assert_eq(InventoryState.get_quantity(&"health_potion"), 1)
	assert_eq(PlayerState.health, PlayerState.max_health - 5)
	InventoryState.clear()
	assert_false(player.drink_potion(), "no potion, no drink")
	player.free()

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
