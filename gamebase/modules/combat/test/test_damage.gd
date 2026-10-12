extends GutTest

## The shared pieces of every fight: health (`Health`), a hit (`Damage`) and
## the sides that hurt each other (`FactionData`).

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

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
