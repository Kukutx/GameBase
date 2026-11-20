extends GutTest

## Afflictions in real time (`AfflictionData`, `Hurtbox.afflict()`): their
## ticks, one laid again, immunity, the player's and a creature's, one that
## slows them, the player's resistance, the HUD's line of those on the player,
## what lays them (a creature's strike or its elite form's, a hazard, a
## weapon's tag) and what is wrong with them.

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")
const HOSTILE_CREATURE_SCENE := preload("res://tiamat/modules/combat/combat/hostile_creature.tscn")
const HP := &"fixture_hp"
## Three ticks of 2, a tenth of a second apart.
const BURN := &"fixture_burn"
## Three ticks of 1, a fifth of a second apart.
const POISON := &"fixture_poison"
## Half speed for three tenths of a second, taking no health.
const SLOW := &"fixture_slow"

var _vitals_snapshot: Dictionary
var _inventory_snapshot: Dictionary
var _world_snapshot: Dictionary
var _reduced_motion := false
var _options: GameOptions

func before_each() -> void:
	_reduced_motion = GameSettings.reduced_motion
	GameSettings.reduced_motion = true
	_options = GameSettings.options
	GameSettings.options = GameOptions.new(CombatModule.new().get_options())
	_vitals_snapshot = Vitals.to_save_data()
	_inventory_snapshot = InventoryState.to_save_data()
	_world_snapshot = WorldState.to_save_data()
	ContentFixture.use(self, _fixture_content())
	var settings := CombatSettings.new()
	settings.health_vital_id = HP
	ContentFixture.use_settings(self, [settings])
	InventoryState.clear()
	WorldState.clear()
	Vitals.reset_new_game()

func after_each() -> void:
	# GUT frees the fixture content only after this hook.
	ContentRegistry.active = ContentDB
	Vitals.load_save_data(_vitals_snapshot)
	InventoryState.load_save_data(_inventory_snapshot)
	WorldState.load_save_data(_world_snapshot)
	GameSettings.reduced_motion = _reduced_motion
	GameSettings.options = _options
	FightState.end_fight()

func test_an_affliction_takes_health_on_its_ticks_until_it_wears_off() -> void:
	var hurtbox := _actor(FactionData.MONSTERS)
	var burn := AfflictionData.find(BURN)
	watch_signals(hurtbox)
	var hit := Damage.new(5, FactionData.PLAYER)
	hit.affliction_id = BURN
	assert_true(hurtbox.receive(hit))
	assert_true(hurtbox.is_afflicted(BURN), "the hit lays it")
	assert_eq(hurtbox.get_afflictions().size(), 1)
	assert_eq(hurtbox.get_afflictions()[0], burn)
	assert_signal_emitted_with_parameters(hurtbox, "afflicted", [burn])
	assert_signal_emit_count(hurtbox, "ailed", 0, "no tick with the hit")
	assert_true(await wait_until(func() -> bool: return not hurtbox.is_afflicted(BURN), 1.0), "it wears off")
	assert_signal_emit_count(hurtbox, "ailed", 3, "a tick each tenth of a second for three tenths")
	var tick: Damage = get_signal_parameters(hurtbox, "ailed")[0]
	assert_eq([tick.amount, tick.faction, tick.knockback], [2, FactionData.PLAYER, Vector2.ZERO], "of its damage, from the side that laid it, with no push")
	await wait_physics_frames(3)
	assert_false(hurtbox.is_physics_processing(), "nothing left to run")

func test_laid_again_it_lasts_anew_but_its_next_tick_stays_due() -> void:
	var hurtbox := _actor(FactionData.MONSTERS)
	var poison := AfflictionData.find(POISON)
	watch_signals(hurtbox)
	assert_true(hurtbox.afflict(poison, FactionData.PLAYER))
	await wait_physics_frames(18)
	assert_signal_emit_count(hurtbox, "ailed", 1, "its first tick, a fifth of a second in")
	assert_true(hurtbox.afflict(poison, FactionData.PLAYER), "laid again halfway to the next")
	assert_signal_emit_count(hurtbox, "afflicted", 1, "it took hold only once")
	await wait_physics_frames(9)
	assert_signal_emit_count(hurtbox, "ailed", 2, "the next came when it was due, so quick hits never put a tick off")
	assert_true(await wait_until(func() -> bool: return not hurtbox.is_afflicted(POISON), 2.0))
	assert_signal_emit_count(hurtbox, "ailed", 4, "three ticks from the second, not six in all")

func test_an_immune_hurtbox_or_one_turned_off_takes_none() -> void:
	var hurtbox := _actor(FactionData.MONSTERS)
	hurtbox.immune_to.assign([BURN])
	var hit := Damage.new(5, FactionData.PLAYER)
	hit.affliction_id = BURN
	assert_true(hurtbox.receive(hit), "the hit still hurts")
	assert_false(hurtbox.is_afflicted(BURN), "but lays nothing")
	assert_false(hurtbox.afflict(AfflictionData.find(BURN)))
	assert_false(hurtbox.afflict(null))
	assert_true(hurtbox.afflict(AfflictionData.find(POISON)), "what it is not immune to")
	hurtbox.enabled = false
	assert_eq(hurtbox.get_afflictions().size(), 0, "turned off, it is cured")
	assert_false(hurtbox.afflict(AfflictionData.find(POISON)))

func test_the_player_is_told_and_burns_until_they_have_no_health_left() -> void:
	var hurtbox := _player(Vector2(5200, 5000))
	watch_signals(CombatEvents)
	watch_signals(GameEvents)
	var hit := Damage.new(10, FactionData.MONSTERS)
	hit.affliction_id = BURN
	assert_true(hurtbox.receive(hit))
	assert_signal_emitted_with_parameters(GameEvents, "toast_requested", ["Afflicted: Burn"])
	assert_true(await wait_until(func() -> bool: return not hurtbox.is_afflicted(BURN), 1.0))
	assert_eq(Vitals.get_value(HP), 84, "the hit and three ticks of 2, through the moment after the hit")
	assert_signal_emit_count(CombatEvents, "player_hurt", 4)
	assert_signal_emitted_with_parameters(CombatEvents, "player_hurt", [2])
	assert_true(hurtbox.afflict(AfflictionData.find(BURN), FactionData.MONSTERS))
	Vitals.load_save_data({String(HP): {"value": 0}})
	await wait_physics_frames(25)
	assert_signal_emit_count(CombatEvents, "player_hurt", 4, "a player with no health left takes no tick")
	assert_false(hurtbox.afflict(AfflictionData.find(BURN)), "nor is laid with one")

func test_one_that_slows_slows_the_player_and_a_creature_while_it_lasts() -> void:
	var hurtbox := _player(Vector2(5200, 5000))
	var slow := AfflictionData.find(SLOW)
	var before := GameStats.get_multiplier(TopDownPlayer.MOVE_SPEED_STAT)
	watch_signals(hurtbox)
	watch_signals(GameStats)
	assert_true(hurtbox.afflict(slow, FactionData.MONSTERS))
	assert_eq(hurtbox.get_speed_scale(), 0.5)
	assert_almost_eq(GameStats.get_multiplier(TopDownPlayer.MOVE_SPEED_STAT), before * 0.5, 0.0001, "the player's steps at half speed")
	assert_signal_emitted_with_parameters(hurtbox, "slowed", [0.5])
	assert_signal_emitted(GameStats, "changed", "what reads the stats reads them again")
	assert_true(await wait_until(func() -> bool: return not hurtbox.is_afflicted(SLOW), 1.0), "it wears off")
	assert_signal_emit_count(hurtbox, "ailed", 0, "taking no health")
	assert_eq(hurtbox.get_speed_scale(), 1.0)
	assert_almost_eq(GameStats.get_multiplier(TopDownPlayer.MOVE_SPEED_STAT), before, 0.0001, "and the player walks as fast as ever")
	var slime := _creature(&"fixture_slime", Vector2(-5600, -5000))
	assert_true(slime.hurtbox.afflict(slow, FactionData.PLAYER))
	slime.call("_walk", Vector2.RIGHT, Vector2.RIGHT)
	assert_almost_eq(slime.velocity.x, slime.data.move_speed * 0.5, 0.001, "a creature walks at half speed too")

func test_the_player_resists_by_a_stat_lasting_shorter_or_not_at_all() -> void:
	var hurtbox := _player(Vector2(5200, 5000))
	var ward := _Ward.new()
	GameStats.register_source(ward)
	watch_signals(CombatEvents)
	assert_eq(hurtbox.get_affliction_scale(AfflictionData.find(BURN)), 0.5)
	assert_true(hurtbox.afflict(AfflictionData.find(BURN), FactionData.MONSTERS))
	assert_true(await wait_until(func() -> bool: return not hurtbox.is_afflicted(BURN), 1.0))
	assert_signal_emit_count(CombatEvents, "player_hurt", 1, "half its three tenths: a single tick")
	ward.scale = 0.0
	assert_false(hurtbox.afflict(AfflictionData.find(BURN), FactionData.MONSTERS), "at 0 it never takes hold")
	assert_false(hurtbox.is_afflicted(BURN))
	assert_false(hurtbox.is_physics_processing())
	GameStats.unregister_source(ward)
	assert_eq(hurtbox.get_affliction_scale(AfflictionData.find(BURN)), 1.0)
	assert_eq((autofree(Hurtbox.new()) as Hurtbox).get_affliction_scale(null), 1.0, "a creature's lasts whole")

func test_the_hud_tells_the_afflictions_on_the_player_until_they_wear_off() -> void:
	var line: AfflictionLine = add_child_autofree(AfflictionLine.new())
	await wait_process_frames(2)
	assert_false(line.visible, "it hides with none")
	assert_false(line.is_processing())
	var hurtbox := _player(Vector2(5200, 5000))
	watch_signals(hurtbox)
	watch_signals(CombatEvents)
	assert_true(hurtbox.afflict(AfflictionData.find(POISON), FactionData.MONSTERS))
	assert_true(hurtbox.afflict(AfflictionData.find(SLOW), FactionData.MONSTERS))
	assert_almost_eq(hurtbox.get_affliction_seconds_left(POISON), 0.6, 0.0001)
	await wait_process_frames(1)
	assert_eq(line.text, "Poison 1s · Slow 1s")
	assert_true(line.visible)
	assert_true(line.is_processing(), "counting their seconds down")
	assert_true(await wait_until(func() -> bool: return line.text == "Poison 1s", 1.0), "the slow wore off first")
	assert_true(await wait_until(func() -> bool: return not line.visible, 1.0), "then the poison")
	assert_false(line.is_processing())
	assert_signal_emit_count(hurtbox, "afflictions_changed", 4, "two took hold, two wore off")
	assert_signal_emit_count(CombatEvents, "player_afflictions_changed", 4)
	hurtbox.cure()
	assert_signal_emit_count(hurtbox, "afflictions_changed", 4, "lifting none changes nothing")
	assert_true(hurtbox.afflict(AfflictionData.find(POISON), FactionData.MONSTERS))
	hurtbox.cure()
	assert_signal_emit_count(hurtbox, "afflictions_changed", 6, "lifting some does")

func test_a_creature_s_strike_lays_its_kind_s_or_its_elite_form_s() -> void:
	var target := _player(Vector2(5600, 5000))
	var slime := _creature(&"fixture_slime", Vector2(5610, 5000))
	assert_true(await wait_until(func() -> bool: return not Vitals.is_full(HP), 1.0), "struck")
	assert_true(target.is_afflicted(BURN), "its kind's burn")
	slime.free()
	target.cure()
	assert_true(await wait_until(func() -> bool: return not target.is_invincible(), 2.0))
	var venomous := EliteData.new()
	venomous.id = &"fixture_venomous"
	venomous.display_name = "Venomous %s"
	venomous.affliction_id = POISON
	_creature(&"fixture_slime", Vector2(5610, 5000), venomous)
	assert_true(await wait_until(func() -> bool: return target.is_afflicted(POISON), 2.0), "its elite form's poison")
	assert_false(target.is_afflicted(BURN), "in place of its kind's")

func test_a_tick_takes_a_creature_s_health_without_a_stun_unless_its_kind_is_immune() -> void:
	var slime := _creature(&"fixture_slime", Vector2(-5600, -5000))
	watch_signals(CombatEvents)
	assert_true(slime.hurtbox.afflict(AfflictionData.find(BURN), FactionData.PLAYER))
	assert_true(await wait_until(func() -> bool: return not slime.hurtbox.is_afflicted(BURN), 1.0))
	assert_eq(slime.health.current, 24, "three ticks of 2")
	assert_signal_emit_count(CombatEvents, "enemy_hurt", 3)
	assert_signal_emitted_with_parameters(CombatEvents, "enemy_hurt", [&"fixture_slime", 2, Vector2(-5600, -5000)])
	assert_ne(slime.get_state(), HostileCreature.STATE_HURT, "no tick stuns it")
	assert_true(slime.take_damage(21))
	assert_true(slime.hurtbox.afflict(AfflictionData.find(BURN), FactionData.PLAYER))
	assert_true(await wait_until(func() -> bool: return slime.is_defeated, 1.0), "a tick can fell it")
	assert_false(slime.hurtbox.is_afflicted(BURN), "and the rest of it goes")
	var wisp := _creature(&"fixture_wisp", Vector2(-5800, -5000))
	assert_eq(wisp.hurtbox.immune_to, [BURN], "its kind's immunity")
	assert_false(wisp.hurtbox.afflict(AfflictionData.find(BURN), FactionData.PLAYER))

func test_a_hazard_s_flare_lays_its_affliction() -> void:
	var at := Vector2(9000, 7000)
	var hazard := Hazard.new()
	hazard.global_position = at
	hazard.rest_seconds = 0.0
	hazard.affliction_id = POISON
	add_child_autofree(hazard)
	var target := Hurtbox.new()
	target.collision_layer = 2
	target.collision_mask = 0
	target.faction = FactionData.PLAYER
	target.global_position = at
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	target.add_child(shape)
	add_child_autofree(target)
	assert_true(await wait_until(func() -> bool: return target.is_afflicted(POISON), 1.0))
	var spread := HazardSpread.new()
	spread.affliction_id = BURN
	var made := spread.make(spread.from_depth)
	assert_eq(made.affliction_id, BURN, "a spread lays its own on each it makes")
	made.free()
	assert_eq(spread.find_problems(), PackedStringArray())
	spread.affliction_id = &"fixture_missing"
	assert_eq(spread.find_problems(), PackedStringArray(["lays unknown affliction 'fixture_missing'"]))

func test_a_weapon_that_carries_an_affliction_s_tag_lays_it() -> void:
	assert_eq(WeaponUse.affliction_of(ItemData.find(&"fixture_brand")), AfflictionData.find(BURN))
	assert_null(WeaponUse.affliction_of(ItemData.find(&"fixture_gel")), "an item without the tag")
	assert_null(WeaponUse.affliction_of(null))
	assert_eq(AfflictionData.find_all().size(), 3, "the burn, the poison and the slow")

func test_what_is_wrong_with_an_affliction_or_what_names_one() -> void:
	var burn := AfflictionData.find(BURN)
	assert_eq(burn.get_ticks(), 3, "three tenths in tenths, rounding aside")
	assert_eq(burn.find_problems(ContentRegistry.active), PackedStringArray())
	var odd := AfflictionData.new()
	odd.id = &"fixture_odd"
	odd.seconds = 0.5
	odd.tick_seconds = 2.0
	assert_eq(odd.find_problems(ContentRegistry.active), PackedStringArray(["has no display name", "takes health every 2.0s but lasts only 0.5s"]))
	var idle := _affliction(&"fixture_idle", "Idle", 1.0, 0.5, 0)
	assert_eq(idle.find_problems(ContentRegistry.active), PackedStringArray(["takes no health and slows nothing"]))
	idle.speed_scale = 0.5
	assert_true(idle.slows())
	assert_eq(idle.find_problems(ContentRegistry.active), PackedStringArray(), "one that only slows")
	var slime := EnemyData.find(&"fixture_slime")
	assert_eq(slime.find_problems(ContentRegistry.active), PackedStringArray())
	slime.affliction_id = &"fixture_missing"
	slime.immune_to.assign([&"fixture_unknown"])
	var problems := slime.find_problems(ContentRegistry.active)
	assert_has(problems, "lays unknown affliction 'fixture_missing'")
	assert_has(problems, "is immune to unknown affliction 'fixture_unknown'")
	var elite := EliteData.new()
	elite.id = &"fixture_odd_elite"
	elite.display_name = "Odd %s"
	elite.affliction_id = &"fixture_missing"
	assert_eq(elite.find_problems(ContentRegistry.active), PackedStringArray(["lays unknown affliction 'fixture_missing'"]))

# A body of `faction` with a hurtbox that no hit makes invincible, at the
# origin.
func _actor(faction: StringName) -> Hurtbox:
	var body := CharacterBody2D.new()
	var shape := CollisionShape2D.new()
	shape.shape = CircleShape2D.new()
	body.add_child(shape)
	var hurtbox := Hurtbox.new()
	hurtbox.faction = faction
	hurtbox.invincible_seconds = 0.0
	body.add_child(hurtbox)
	add_child_autofree(body)
	return hurtbox

# The player at `at`, whose hurtbox creatures strike.
func _player(at: Vector2) -> PlayerHurtbox:
	var player := CharacterBody2D.new()
	player.add_to_group(&"player")
	var hurtbox := PlayerHurtbox.new()
	player.add_child(hurtbox)
	player.global_position = at
	add_child_autofree(player)
	return hurtbox

func _creature(enemy_id: StringName, at: Vector2, elite: EliteData = null) -> HostileCreature:
	var creature := HOSTILE_CREATURE_SCENE.instantiate() as HostileCreature
	creature.data = EnemyData.find(enemy_id)
	creature.elite = elite
	creature.persistent_id = &""
	creature.global_position = at
	add_child_autofree(creature)
	return creature

# The player's health, a burn, a poison and a slow, a slime of 30 health
# whose hits burn, a wisp that never burns and a brand whose tag burns.
func _fixture_content() -> Array:
	var burn := _affliction(BURN, "Burn", 0.3, 0.1, 2)
	burn.weapon_tag = "fixture_burns"
	var poison := _affliction(POISON, "Poison", 0.6, 0.2, 1)
	var slow := _affliction(SLOW, "Slow", 0.3, 0.1, 0)
	slow.speed_scale = 0.5
	var gel := ItemData.new()
	gel.id = &"fixture_gel"
	gel.display_name = "Gel"
	var brand := ItemData.new()
	brand.id = &"fixture_brand"
	brand.display_name = "Brand"
	brand.tags = PackedStringArray(["weapon", "fixture_burns"])
	var slime := EnemyData.new()
	slime.id = &"fixture_slime"
	slime.display_name = "Slime"
	slime.max_health = 30
	slime.affliction_id = BURN
	slime.drop_item_id = gel.id
	slime.drop_quantity = 1
	var wisp := EnemyData.new()
	wisp.id = &"fixture_wisp"
	wisp.display_name = "Wisp"
	wisp.immune_to.assign([BURN])
	return [burn, poison, slow, gel, brand, slime, wisp, ContentFixture.vital(HP)]

# A stat source that has afflictions last `scale` times as long on the
# player.
class _Ward extends RefCounted:
	var scale := 0.5

	func get_stat_multiplier(stat: StringName) -> float:
		return scale if stat == PlayerHurtbox.AFFLICTION_SECONDS_STAT else 1.0

	func get_stat_bonus(_stat: StringName) -> float:
		return 0.0

static func _affliction(id: StringName, display_name: String, seconds: float, tick_seconds: float, tick_damage: int) -> AfflictionData:
	var affliction := AfflictionData.new()
	affliction.id = id
	affliction.display_name = display_name
	affliction.seconds = seconds
	affliction.tick_seconds = tick_seconds
	affliction.tick_damage = tick_damage
	return affliction
