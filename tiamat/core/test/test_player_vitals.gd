extends GutTest

## The player's vitals (`Vitals`, `VitalData`): spending, restoring and
## draining them within their maximum, what a vital the game lacks does, a
## maximum that follows a stat, and what a save keeps.

const ContentFixture := preload("res://tiamat/core/test/content_fixture.gd")

var _vitals: PlayerVitals

func before_each() -> void:
	ContentFixture.use(self, [_vital(&"fixture_stamina", 120, true), _vital(&"fixture_focus", 30, false)])
	_vitals = PlayerVitals.new()
	add_child_autofree(_vitals)

func test_a_vital_stays_between_nothing_and_its_maximum() -> void:
	watch_signals(_vitals)
	assert_true(_vitals.has_vital(&"fixture_stamina"))
	assert_eq(_vitals.get_value(&"fixture_stamina"), 120, "a vital starts full")
	assert_true(_vitals.spend(&"fixture_stamina", 25))
	assert_eq(_vitals.get_value(&"fixture_stamina"), 95)
	assert_false(_vitals.spend(&"fixture_stamina", 96), "not that much")
	assert_eq(_vitals.get_value(&"fixture_stamina"), 95)
	assert_eq(_vitals.restore(&"fixture_stamina", 40), 25, "up to its maximum")
	assert_true(_vitals.is_full(&"fixture_stamina"))
	assert_eq(_vitals.drain(&"fixture_stamina", 500), 120, "down to nothing")
	assert_eq(_vitals.drain(&"fixture_stamina", 5), 0)
	assert_signal_emitted_with_parameters(_vitals, "changed", [&"fixture_stamina", 0, 120])
	assert_signal_emit_count(_vitals, "depleted", 1)
	assert_signal_emitted_with_parameters(_vitals, "depleted", [&"fixture_stamina"])
	assert_almost_eq(_vitals.get_fraction(&"fixture_stamina"), 0.0, 0.001)
	_vitals.set_value(&"fixture_stamina", 60)
	assert_almost_eq(_vitals.get_fraction(&"fixture_stamina"), 0.5, 0.001)
	assert_eq(_vitals.describe(&"fixture_stamina"), "Stamina 60/120")

func test_a_vital_the_game_lacks_costs_nothing_and_holds_nothing() -> void:
	for vital_id: StringName in [&"", &"fixture_mana"]:
		assert_false(_vitals.has_vital(vital_id))
		assert_true(_vitals.spend(vital_id, 10), "free")
		assert_eq(_vitals.get_value(vital_id), 0)
		assert_eq(_vitals.restore(vital_id, 10), 0)
		assert_eq(_vitals.drain(vital_id, 10), 0)
		assert_false(_vitals.is_full(vital_id))
		assert_eq(_vitals.describe(vital_id), "")
	assert_true(_vitals.spend(&"fixture_stamina", 0), "nothing costs nothing")
	assert_true(_vitals.spend(&"fixture_stamina", -4))
	assert_eq(_vitals.get_value(&"fixture_stamina"), 120)

func test_not_enough_tells_the_player() -> void:
	_vitals.set_value(&"fixture_focus", 2)
	watch_signals(GameEvents)
	assert_false(_vitals.try_spend(&"fixture_focus", 3))
	assert_signal_emitted_with_parameters(GameEvents, "toast_requested", ["Not enough Focus"])
	assert_true(_vitals.try_spend(&"fixture_focus", 2))
	assert_signal_emit_count(GameEvents, "toast_requested", 1)

func test_sleep_refills_only_what_sleep_refills() -> void:
	_vitals.set_value(&"fixture_stamina", 1)
	_vitals.set_value(&"fixture_focus", 1)
	_vitals.refill_after_sleep()
	assert_true(_vitals.is_full(&"fixture_stamina"))
	assert_eq(_vitals.get_value(&"fixture_focus"), 1)
	_vitals.reset_new_game()
	assert_true(_vitals.is_full(&"fixture_focus"), "a new game fills every vital")

func test_a_save_keeps_each_value_and_maximum() -> void:
	_vitals.set_maximum(&"fixture_stamina", 150)
	_vitals.set_value(&"fixture_stamina", 95)
	_vitals.set_maximum(&"fixture_focus", 10)
	assert_eq(_vitals.get_value(&"fixture_focus"), 10, "the value stays within a lower maximum")
	var restored := PlayerVitals.new()
	add_child_autofree(restored)
	restored.load_save_data(_vitals.to_save_data())
	assert_eq(restored.get_maximum(&"fixture_stamina"), 150)
	assert_eq(restored.get_value(&"fixture_stamina"), 95)
	assert_eq(restored.get_value(&"fixture_focus"), 10)
	var saved := _vitals.to_save_data()
	VitalData.find(&"fixture_stamina").maximum = 130
	restored.load_save_data(saved)
	assert_eq(restored.get_maximum(&"fixture_stamina"), 160, "the upgrade on top of the vital's maximum as the game now has it")
	VitalData.find(&"fixture_stamina").maximum = 120
	restored.load_save_data({"fixture_stamina": {"value": 900, "bonus": "lots"}, "fixture_gone": {"value": 1}})
	assert_eq(restored.get_maximum(&"fixture_stamina"), 120, "a damaged bonus reads as none")
	assert_eq(restored.get_value(&"fixture_stamina"), 120, "a value within it")
	assert_true(restored.is_full(&"fixture_focus"), "a vital the save lacks starts full")
	assert_false(restored.to_save_data().has("fixture_gone"), "only the game's vitals are kept")

func test_a_maximum_that_follows_a_stat_rises_filled_and_falls_with_it() -> void:
	ContentFixture.add_stat(self, &"fixture_vigor")
	var hardy := _vital(&"fixture_hardy", 100, true)
	hardy.maximum_stat = &"fixture_vigor"
	ContentFixture.use(self, [hardy])
	var vitals := PlayerVitals.new()
	add_child_autofree(vitals)
	vitals.drain(&"fixture_hardy", 30)
	watch_signals(vitals)
	var source := _Vigor.new()
	GameStats.register_source(source)
	source.bonus = 20.0
	GameStats.notify_changed()
	assert_eq(vitals.get_maximum(&"fixture_hardy"), 120)
	assert_eq(vitals.get_value(&"fixture_hardy"), 90, "the 20 more come filled")
	assert_signal_emitted_with_parameters(vitals, "changed", [&"fixture_hardy", 90, 120])
	source.multiplier = 1.5
	GameStats.notify_changed()
	assert_eq(vitals.get_maximum(&"fixture_hardy"), 180, "the bonus, then the multiplier")
	assert_eq(vitals.restore(&"fixture_hardy", 500), 30)
	var saved := vitals.to_save_data()
	GameStats.unregister_source(source)
	assert_eq(vitals.get_maximum(&"fixture_hardy"), 100)
	assert_eq(vitals.get_value(&"fixture_hardy"), 100, "the value falls to the maximum")
	assert_eq(saved, {"fixture_hardy": {"value": 180, "bonus": 0}}, "a save keeps the vital's own maximum")
	# A save loads before what the stats follow (the world's upgrades) does.
	vitals.load_save_data(saved)
	GameStats.register_source(source)
	await wait_process_frames(1)
	assert_eq(vitals.get_value(&"fixture_hardy"), 180, "kept once the stats are read again")
	GameStats.unregister_source(source)
	vitals.load_save_data(saved)
	await wait_process_frames(1)
	assert_eq(vitals.get_value(&"fixture_hardy"), 100, "and within the maximum they make")
	var lost := _vital(&"fixture_lost", 10, true)
	lost.maximum_stat = &"fixture_nothing"
	assert_eq(lost.find_problems(ContentDB), PackedStringArray(["follows stat 'fixture_nothing', which no installed module or the game reads"]))

func test_a_vital_needs_a_name() -> void:
	var nameless := _vital(&"fixture_nameless", 10, true)
	nameless.display_name = " "
	nameless.maximum = 0
	assert_eq(nameless.find_problems(ContentDB), PackedStringArray(["has no display name", "maximum 0 is not at least 1"]))
	var registry := ContentFixture.use(self, [_vital(&"fixture_stamina", 120, true)])
	assert_eq(VitalData.find_reference_problems(registry, "energy vital", &"fixture_stamina"), PackedStringArray())
	assert_eq(VitalData.find_reference_problems(registry, "energy vital", &""), PackedStringArray(), "none named")
	assert_eq(VitalData.find_reference_problems(registry, "energy vital", &"fixture_mana"), PackedStringArray(["energy vital 'fixture_mana' is no vital"]))

static func _vital(id: StringName, maximum: int, refill_on_sleep: bool) -> VitalData:
	var vital := VitalData.new()
	vital.id = id
	vital.display_name = String(id).trim_prefix("fixture_").capitalize()
	vital.maximum = maximum
	vital.refill_on_sleep = refill_on_sleep
	return vital

class _Vigor:
	extends RefCounted
	var multiplier := 1.0
	var bonus := 0.0

	func get_stat_multiplier(stat: StringName) -> float:
		return multiplier if stat == &"fixture_vigor" else 1.0

	func get_stat_bonus(stat: StringName) -> float:
		return bonus if stat == &"fixture_vigor" else 0.0
