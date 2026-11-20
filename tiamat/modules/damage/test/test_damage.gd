extends GutTest

## The shared pieces of every fight: health (`Health`), a hit (`Damage`), the
## afflictions on a thing (`Afflictions`), the sides that hurt each other
## (`FactionData`) and a time limit (`BattleTimeLimit`).

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")

func after_each() -> void:
	ContentRegistry.active = ContentDB

func test_health_goes_down_and_up_between_zero_and_its_maximum() -> void:
	var health := Health.new(30)
	watch_signals(health)
	assert_eq(health.current, 30)
	assert_eq(health.take(12), 12)
	assert_signal_emitted_with_parameters(health, "changed", [18, 30])
	assert_eq(health.heal(50), 12, "no more than the maximum")
	assert_eq(health.take(0), 0)
	assert_eq(health.take(-4), 0)
	assert_eq(health.get_fraction(), 1.0)
	assert_eq(health.take(99), 30, "no more than it has")
	assert_true(health.is_depleted())
	assert_signal_emit_count(health, "depleted", 1)
	assert_eq(health.take(5), 0)
	assert_eq(health.heal(5), 0, "nothing heals what is depleted")
	health.reset(40)
	assert_eq([health.current, health.maximum], [40, 40])
	health.set_current(99)
	assert_eq(health.current, 40)
	assert_eq(Health.new(-3).maximum, 1)

func test_a_hit_takes_no_less_than_nothing() -> void:
	var source := Node.new()
	var damage := Damage.new(-5, &"fixture_side", source, Vector2(3, 0))
	assert_eq(damage.amount, 0)
	assert_eq(damage.faction, &"fixture_side")
	assert_eq(damage.source, source)
	assert_eq(damage.knockback, Vector2(3, 0))
	source.free()

func test_any_two_sides_fight_unless_one_is_the_other_s_ally() -> void:
	var pets := FactionData.new()
	pets.id = &"fixture_pets"
	pets.allies = [FactionData.PLAYER]
	ContentFixture.use(self, [pets])
	assert_false(FactionData.are_hostile(&"fixture_pets", FactionData.PLAYER))
	assert_false(FactionData.are_hostile(FactionData.PLAYER, &"fixture_pets"), "an alliance goes both ways")
	assert_true(FactionData.are_hostile(FactionData.MONSTERS, &"fixture_pets"))
	assert_false(FactionData.are_hostile(FactionData.MONSTERS, FactionData.MONSTERS), "a side never hurts itself")
	assert_true(FactionData.are_hostile(&"", FactionData.PLAYER), "damage of no side hurts every side")
	assert_true(FactionData.are_hostile(FactionData.PLAYER, &""))

func test_a_faction_s_allies_are_checked() -> void:
	var odd := FactionData.new()
	odd.id = &"fixture_odd"
	odd.allies = [&"fixture_odd", &"", FactionData.PLAYER]
	var registry := ContentFixture.use(self, [odd])
	assert_eq(registry.find_entry_problems(odd), PackedStringArray([
		"faction 'fixture_odd' lists itself among its allies",
		"faction 'fixture_odd' lists an empty faction among its allies",
	]))

func test_a_time_limit_runs_out_for_the_side_that_holds_out() -> void:
	var guard := FactionData.new()
	guard.id = &"fixture_guard"
	guard.allies.assign([FactionData.PLAYER])
	ContentFixture.use(self, [guard])
	var limit := BattleTimeLimit.new(90.0, FactionData.PLAYER)
	assert_eq([limit.get_left(30.0), limit.get_left(120.0)], [60.0, 0.0])
	assert_false(limit.is_up(89.5))
	assert_true(limit.is_up(90.0 - 0.0000001), "a rounding short of the limit reaches it")
	assert_true(limit.wins(FactionData.PLAYER) and limit.wins(&"fixture_guard"), "the player's side, allies and all")
	assert_false(limit.wins(FactionData.MONSTERS))
	assert_eq(BattleTimeLimit.new(-5.0, FactionData.MONSTERS).seconds, 0.0)

func test_afflictions_tick_last_anew_when_laid_again_and_stop_once_lifted() -> void:
	var poison := AfflictionData.new()
	poison.id = &"fixture_poison"
	poison.display_name = "Poison"
	poison.seconds = 3.0
	poison.tick_seconds = 1.0
	poison.tick_damage = 2
	var on := Afflictions.new()
	var ticks: Array = []
	var record := func(affliction: AfflictionData, tick: Damage) -> void: ticks.append([affliction.id, tick.amount, tick.faction, tick.knockback])
	assert_eq(on.get_next_tick(), INF, "none on it")
	assert_false(on.lay(null))
	assert_true(on.lay(poison, FactionData.MONSTERS), "it takes hold")
	assert_eq(on.get_all(), [poison] as Array[AfflictionData])
	assert_eq(on.get_next_tick(), 1.0)
	on.advance(0.5, record)
	assert_eq(ticks.size(), 0)
	assert_false(on.lay(poison, FactionData.MONSTERS), "laid again, it was on already")
	assert_almost_eq(on.get_next_tick(), 0.5, 0.0001, "its next tick still due when it was")
	on.advance(1.0, record)
	assert_eq(ticks, [[&"fixture_poison", 2, FactionData.MONSTERS, Vector2.ZERO]], "its damage, from the side that laid it, with no push")
	on.advance(5.0, record)
	assert_eq(ticks.size(), 3, "three ticks from the second laying, a long step taking each due in it")
	assert_true(on.is_empty(), "then it wears off")
	assert_false(on.has(&"fixture_poison"))
	on.lay(poison)
	on.advance(5.0, func(_affliction: AfflictionData, _tick: Damage) -> void:
		ticks.append(null)
		on.clear())
	assert_eq(ticks.size(), 4, "a tick that lifts the rest, a defeat, ends it")
