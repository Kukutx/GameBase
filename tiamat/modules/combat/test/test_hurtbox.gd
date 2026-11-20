extends GutTest

## Real-time hits (`Hurtbox`, `PlayerHurtbox`): which side's damage hurts, the
## invincibility after a hit, the knockback, the flash, and the player's, at
## the player's choice of how hard hits land on them.

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")
const HP := &"fixture_hp"

var _vitals_snapshot: Dictionary
var _reduced_motion := false
var _options: GameOptions

func before_each() -> void:
	_vitals_snapshot = Vitals.to_save_data()
	_reduced_motion = GameSettings.reduced_motion
	_options = GameSettings.options
	GameSettings.options = GameOptions.new(CombatModule.new().get_options())
	ContentFixture.use(self, [ContentFixture.vital(HP)])
	var settings := CombatSettings.new()
	settings.health_vital_id = HP
	ContentFixture.use_settings(self, [settings])
	Vitals.reset_new_game()

func after_each() -> void:
	ContentRegistry.active = ContentDB
	Vitals.load_save_data(_vitals_snapshot)
	GameSettings.reduced_motion = _reduced_motion
	GameSettings.options = _options

func test_only_damage_of_a_hostile_side_hurts() -> void:
	var hurtbox := _actor(FactionData.MONSTERS)
	watch_signals(hurtbox)
	assert_false(hurtbox.receive(Damage.new(5, FactionData.MONSTERS)), "a side never hurts itself")
	assert_false(hurtbox.receive(Damage.new(0, FactionData.PLAYER)), "no damage")
	assert_false(hurtbox.receive(null))
	var damage := Damage.new(5, FactionData.PLAYER)
	assert_true(hurtbox.receive(damage))
	assert_signal_emitted_with_parameters(hurtbox, "hurt", [damage])
	assert_eq(Hurtbox.of(hurtbox.get_parent()), hurtbox)
	assert_null(Hurtbox.of(hurtbox))
	hurtbox.enabled = false
	await wait_physics_frames(30)
	assert_false(hurtbox.receive(Damage.new(5, FactionData.PLAYER)), "a hurtbox that is off")

func test_no_hit_hurts_for_a_moment_after_one() -> void:
	var hurtbox := _actor(FactionData.MONSTERS)
	hurtbox.invincible_seconds = 0.05
	assert_true(hurtbox.receive(Damage.new(5, FactionData.PLAYER)))
	assert_true(hurtbox.is_invincible())
	assert_false(hurtbox.receive(Damage.new(5, FactionData.PLAYER)))
	await wait_physics_frames(6)
	assert_false(hurtbox.is_invincible())
	assert_true(hurtbox.receive(Damage.new(5, FactionData.PLAYER)))

func test_a_hit_pushes_the_actor_back_and_flashes_it() -> void:
	var hurtbox := _actor(FactionData.MONSTERS)
	var body := hurtbox.get_parent() as CharacterBody2D
	body.modulate = Color(0.5, 1.0, 1.0)
	assert_true(hurtbox.receive(Damage.new(1, FactionData.PLAYER, null, Vector2(120, 0))))
	assert_eq(body.modulate, Hurtbox.FLASH_COLOR)
	await wait_seconds(Hurtbox.KNOCKBACK_SECONDS + 0.1)
	assert_gt(body.position.x, 4.0, "pushed the way the hit went")
	assert_almost_eq(body.position.y, 0.0, 0.01)
	assert_eq(body.modulate, Color(0.5, 1.0, 1.0), "the flash fades back to how it looked")
	var steady := _actor(FactionData.MONSTERS)
	steady.knockback_scale = 0.0
	assert_true(steady.receive(Damage.new(1, FactionData.PLAYER, null, Vector2(120, 0))))
	await wait_seconds(Hurtbox.KNOCKBACK_SECONDS + 0.1)
	assert_eq((steady.get_parent() as Node2D).position, Vector2.ZERO, "nothing pushes it")

func test_the_player_s_hurtbox_takes_the_player_s_health() -> void:
	GameSettings.reduced_motion = true
	var player := Node2D.new()
	var hurtbox := PlayerHurtbox.new()
	player.add_child(hurtbox)
	add_child_autofree(player)
	watch_signals(CombatEvents)
	assert_false(hurtbox.receive(Damage.new(10, FactionData.PLAYER)), "the player's own side")
	assert_true(hurtbox.receive(Damage.new(10, FactionData.MONSTERS)))
	assert_eq(Vitals.get_value(HP), 90)
	assert_signal_emitted_with_parameters(CombatEvents, "player_hurt", [10])
	assert_true(hurtbox.is_invincible(), "the player gets a moment after a hit")

func test_the_player_chooses_how_hard_hits_land_on_them() -> void:
	GameSettings.reduced_motion = true
	assert_eq(GameSettings.get_option(PlayerHurtbox.DAMAGE_TAKEN_OPTION), "Standard", "the combat module offers the choice, standard at first")
	assert_eq(PlayerHurtbox.damage_taken(10), 10)
	GameSettings.options.set_value(PlayerHurtbox.DAMAGE_TAKEN_OPTION, "Light")
	assert_eq(PlayerHurtbox.damage_taken(10), 5)
	assert_eq(PlayerHurtbox.damage_taken(1), 1, "a hit that does any takes at least 1")
	assert_eq(PlayerHurtbox.damage_taken(0), 0)
	var player := Node2D.new()
	var hurtbox := PlayerHurtbox.new()
	player.add_child(hurtbox)
	add_child_autofree(player)
	watch_signals(CombatEvents)
	assert_true(hurtbox.receive(Damage.new(10, FactionData.MONSTERS)))
	assert_eq(Vitals.get_value(HP), 95, "read at the hit")
	assert_signal_emitted_with_parameters(CombatEvents, "player_hurt", [5])
	GameSettings.options.set_value(PlayerHurtbox.DAMAGE_TAKEN_OPTION, "Heavy")
	assert_eq(PlayerHurtbox.damage_taken(10), 15)
	assert_eq(PlayerHurtbox.damage_taken(3), 5, "rounded")
	var own := GameOption.new_choice(PlayerHurtbox.DAMAGE_TAKEN_OPTION, "Damage Taken", PackedStringArray(["Kind", "Cruel"]))
	GameSettings.options = GameOptions.new([own] as Array[GameOption])
	assert_eq(PlayerHurtbox.damage_taken(10), 10, "a game's choice of its own takes a hit whole")
	GameSettings.options = GameOptions.new()
	assert_eq(PlayerHurtbox.damage_taken(10), 10, "and so does a game without the option")

## Changes how hard hits land on the player, as armour or a boon would.
class _Armour:
	extends RefCounted

	func get_stat_multiplier(stat: StringName) -> float:
		return 0.5 if stat == PlayerHurtbox.INCOMING_DAMAGE_STAT else 1.0

	func get_stat_bonus(stat: StringName) -> float:
		return 1.0 if stat == PlayerHurtbox.INCOMING_DAMAGE_STAT else 0.0

func test_armour_or_a_boon_changes_how_hard_hits_land() -> void:
	var armour := _Armour.new()
	GameStats.register_source(armour)
	var halved := PlayerHurtbox.damage_taken(9)
	GameSettings.options.set_value(PlayerHurtbox.DAMAGE_TAKEN_OPTION, "Heavy")
	var heavy := PlayerHurtbox.damage_taken(10)
	GameStats.unregister_source(armour)
	assert_eq(halved, 5, "(9 + 1) x 0.5")
	assert_eq(heavy, 8, "after the player's choice: (15 + 1) x 0.5")
	assert_eq(PlayerHurtbox.damage_taken(10), 15, "without the armour")

func test_a_hit_staggers_the_player_while_it_pushes_them() -> void:
	GameSettings.reduced_motion = true
	var player := TopDownPlayer.new()
	var hurtbox := PlayerHurtbox.new()
	player.add_child(hurtbox)
	add_child_autofree(player)
	assert_true(hurtbox.receive(Damage.new(1, FactionData.MONSTERS, null, Vector2(0, 90))))
	assert_true(player.is_staggered(), "walking does not cancel the push")
	await wait_seconds(Hurtbox.KNOCKBACK_SECONDS + 0.1)
	assert_false(player.is_staggered())
	assert_gt(player.position.y, 2.0, "pushed the way the hit went")

func test_a_player_without_health_takes_no_more_hits() -> void:
	var player := Node2D.new()
	var hurtbox := PlayerHurtbox.new()
	player.add_child(hurtbox)
	add_child_autofree(player)
	watch_signals(CombatEvents)
	# Loaded, not drained: no defeat takes the player home.
	Vitals.load_save_data({String(HP): {"value": 0}})
	assert_false(hurtbox.receive(Damage.new(10, FactionData.MONSTERS)))
	assert_false(hurtbox.is_invincible(), "nothing of a hit starts")
	assert_signal_not_emitted(CombatEvents, "player_hurt")

func test_turning_a_hurtbox_off_stops_its_push() -> void:
	var hurtbox := _actor(FactionData.MONSTERS)
	assert_true(hurtbox.receive(Damage.new(1, FactionData.PLAYER, null, Vector2(300, 0))))
	hurtbox.enabled = false
	assert_eq(hurtbox.get_knockback_left(), 0.0)
	await wait_seconds(Hurtbox.KNOCKBACK_SECONDS + 0.1)
	assert_eq((hurtbox.get_parent() as Node2D).position, Vector2.ZERO)

# A body of `faction` with a hurtbox, at the origin.
func _actor(faction: StringName) -> Hurtbox:
	var body := CharacterBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	body.add_child(shape)
	var hurtbox := Hurtbox.new()
	hurtbox.faction = faction
	body.add_child(hurtbox)
	add_child_autofree(body)
	return hurtbox
