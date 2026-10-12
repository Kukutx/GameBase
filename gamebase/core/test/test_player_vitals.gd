extends GutTest

## The player's vitals (`Vitals`, `VitalData`): spending, restoring and
## draining them within their maximum, what a vital the game lacks does, and
## what a save keeps.

const ContentFixture := preload("res://gamebase/core/test/content_fixture.gd")

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
