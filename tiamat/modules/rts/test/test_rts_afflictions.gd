extends GutTest

## Afflictions in a command battle (`RtsBattle`): a blow lays its kind's
## affliction on the foe it leaves standing, which takes health in battle
## time until it lifts, lasts anew when laid again without ticking sooner,
## never takes hold of a kind immune to it, brings a unit down as a blow
## would and ends the battle then, and is lifted when its unit falls or a
## healer that cures mends it.

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")
const RtsFixture := preload("res://tiamat/modules/rts/test/rts_fixture.gd")

var _ailed: Array[String] = []
var _ended: Array[bool] = []

func before_each() -> void:
	_ailed.clear()
	_ended.clear()
	ContentFixture.use(self, RtsFixture.entries())

func test_a_blow_lays_its_affliction_which_ticks_in_battle_time_and_lifts() -> void:
	var battle := _battle()
	var torch := RtsFixture.add(battle, &"fixture_torch", FactionData.PLAYER, Vector2(100.0, 80.0))
	var raider := RtsFixture.add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2(110.0, 80.0))
	battle.order_hold([torch] as Array[RtsUnit])
	battle.order_hold([raider] as Array[RtsUnit])
	raider.cooldown = 100.0
	battle.advance(RtsBattle.STEP)
	assert_eq(raider.health.current, 21, "the blow takes its 3")
	assert_true(raider.afflictions.has(&"fixture_burn"), "and lays the burn on the foe it leaves standing")
	battle.advance(1.0 - RtsBattle.STEP)
	assert_eq(_ailed, [] as Array[String], "not before a second of battle time")
	battle.advance(RtsBattle.STEP)
	assert_eq(_ailed, ["fixture_raider fixture_burn 2"] as Array[String], "the burn takes its 2 a second of battle time later")
	torch.cooldown = 100.0
	battle.advance(2.0)
	assert_eq(_ailed.size(), 3, "three times while it lasts")
	assert_false(raider.afflictions.has(&"fixture_burn"), "and lifts after its last")
	assert_eq(raider.health.current, 15)

func test_laid_again_it_lasts_anew_without_ticking_sooner() -> void:
	var battle := _battle()
	var torch := RtsFixture.add(battle, &"fixture_torch", FactionData.PLAYER, Vector2(100.0, 80.0))
	var raider := RtsFixture.add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2(110.0, 80.0))
	battle.order_hold([torch, raider] as Array[RtsUnit])
	raider.cooldown = 100.0
	# A blow every two seconds, at 0, 2 and 4, each laying the burn anew: it
	# ticks at 1, 2, 3, 4 and 5, once a second and never twice.
	battle.advance(5.0 + RtsBattle.STEP)
	assert_eq(_ailed.size(), 5, "once a second of battle time, however often laid")
	assert_eq(raider.health.current, 24 - 3 * 3 - 5 * 2)

func test_a_kind_immune_to_it_never_takes_it() -> void:
	var battle := _battle()
	var torch := RtsFixture.add(battle, &"fixture_torch", FactionData.PLAYER, Vector2(100.0, 80.0))
	var brute := RtsFixture.add(battle, &"fixture_brute", FactionData.MONSTERS, Vector2(112.0, 80.0))
	brute.data.immune_to.assign([&"fixture_burn"])
	battle.order_hold([torch, brute] as Array[RtsUnit])
	brute.cooldown = 100.0
	battle.advance(1.5)
	assert_eq(brute.health.current, 59, "the blow lands, less its armor")
	assert_true(brute.afflictions.is_empty(), "but the burn never takes hold")
	assert_false(brute.can_be_afflicted(RtsUnitData.find(&"fixture_torch").get_affliction()))
	assert_eq(_ailed, [] as Array[String])

func test_a_tick_that_brings_the_last_foe_down_wins_the_battle() -> void:
	var battle := _battle()
	var torch := RtsFixture.add(battle, &"fixture_torch", FactionData.PLAYER, Vector2(100.0, 80.0))
	var raider := RtsFixture.add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2(110.0, 80.0))
	var fallen: Array[RtsUnit] = []
	battle.unit_defeated.connect(func(unit: RtsUnit) -> void: fallen.append(unit))
	battle.order_hold([torch, raider] as Array[RtsUnit])
	raider.cooldown = 100.0
	raider.health.reset(5)
	battle.advance(RtsBattle.STEP)
	assert_eq(raider.health.current, 2)
	torch.cooldown = 100.0
	battle.advance(1.0)
	assert_eq(fallen, [raider] as Array[RtsUnit], "the burn brings it down")
	assert_true(raider.afflictions.is_empty(), "and lifts as it falls")
	assert_eq(_ended, [true] as Array[bool], "the last foe down: the battle is won")

func test_an_affliction_takes_hold_only_of_a_standing_unit() -> void:
	var battle := _battle()
	var raider := RtsFixture.add(battle, &"fixture_raider", FactionData.MONSTERS, Vector2(110.0, 80.0))
	var burn := AfflictionData.find(&"fixture_burn")
	assert_false(raider.afflict(null, FactionData.PLAYER))
	raider.health.take(100)
	assert_false(raider.afflict(burn, FactionData.PLAYER), "a fallen unit takes none")
	assert_true(raider.afflictions.is_empty())

func test_a_healer_that_cures_lifts_the_afflictions_of_the_friend_it_mends() -> void:
	var battle := _battle()
	var medic := RtsFixture.add(battle, &"fixture_medic", FactionData.PLAYER, Vector2(100.0, 80.0))
	var footman := RtsFixture.add(battle, &"fixture_footman", FactionData.PLAYER, Vector2(112.0, 80.0))
	battle.order_hold([medic, footman] as Array[RtsUnit])
	footman.health.take(5)
	assert_true(footman.afflict(AfflictionData.find(&"fixture_burn"), FactionData.MONSTERS))
	battle.advance(RtsBattle.STEP)
	assert_eq(footman.health.current, 29, "mended by 4")
	assert_true(footman.afflictions.has(&"fixture_burn"), "a medic that does not cure leaves the burn")
	medic.data.cures = true
	medic.cooldown = 0.0
	battle.advance(RtsBattle.STEP)
	assert_eq(footman.health.current, 30)
	assert_true(footman.afflictions.is_empty(), "one that cures lifts it as it mends")

func _battle() -> RtsBattle:
	var battle := RtsFixture.battle()
	battle.unit_ailed.connect(func(unit: RtsUnit, affliction: AfflictionData, amount: int) -> void:
		_ailed.append("%s %s %d" % [unit.data.id, affliction.id, amount]))
	battle.ended.connect(func(won: bool) -> void: _ended.append(won))
	return battle
