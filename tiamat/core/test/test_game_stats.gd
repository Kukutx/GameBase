extends GutTest

func test_stats_combine_every_source() -> void:
	var stats := GameStatsService.new()
	autofree(stats)
	stats.register_stat(&"speed")
	assert_true(stats.has_stat(&"speed"))
	assert_false(stats.has_stat(&"jump"))
	var first := _StatSource.new(1.5, 2.0)
	var second := _StatSource.new(0.5, 1.0)
	stats.register_source(first)
	stats.register_source(second)
	stats.register_source(first)
	assert_almost_eq(stats.get_multiplier(&"speed"), 0.75, 0.001)
	assert_almost_eq(stats.get_bonus(&"speed"), 3.0, 0.001)
	assert_almost_eq(stats.apply(&"speed", 7.0), 7.5, 0.001, "bonuses are added before the multipliers")

func test_the_stats_tell_when_they_may_read_otherwise() -> void:
	var stats := GameStatsService.new()
	autofree(stats)
	watch_signals(stats)
	var source := _StatSource.new(2.0, 0.0)
	stats.register_source(source)
	stats.register_source(source)
	assert_signal_emit_count(stats, "changed", 1, "a source added once")
	stats.notify_changed()
	assert_signal_emit_count(stats, "changed", 2, "its changes changed")
	stats.unregister_source(source)
	stats.unregister_source(source)
	assert_signal_emit_count(stats, "changed", 3, "a source removed once")

func test_named_stats_read_out_what_changes_them() -> void:
	var stats := GameStatsService.new()
	autofree(stats)
	stats.register_stat(&"speed", "Speed")
	stats.register_stat(&"vigor", "Vigor")
	stats.register_stat(&"hidden")
	stats.register_stat(&"speed")
	assert_eq(stats.get_stat_name(&"speed"), "Speed", "registering again keeps the name")
	assert_eq(stats.get_stat_name(&"hidden"), "")
	assert_eq(stats.describe_changes({&"speed": 1.1, &"hidden": 2.0, &"vigor": 0.75}, {&"vigor": 15.0}), PackedStringArray([
		"Speed +10%",
		"Vigor +15",
		"Vigor -25%",
	]), "in the order the stats were registered, a nameless one left out")
	assert_eq(stats.describe_changes({&"speed": 1.0, &"vigor": 1.001}, {&"speed": 0.0, &"vigor": -2.5}), PackedStringArray(["Vigor -2.5"]),
		"what changes nothing says nothing")
	stats.register_source(_StatSource.new(1.25, 0.0))
	stats.register_source(_StatSource.new(1.1, 5.0))
	assert_eq(stats.describe_current(), PackedStringArray([
		"Move speed +5", "Move speed +38%", "Speed +5", "Speed +38%", "Vigor +5", "Vigor +38%",
	]), "each source's bonuses summed and multipliers multiplied, the core's own stat first")

class _StatSource:
	extends RefCounted
	var _multiplier: float
	var _bonus: float

	func _init(multiplier: float, bonus: float) -> void:
		_multiplier = multiplier
		_bonus = bonus

	func get_stat_multiplier(_stat: StringName) -> float:
		return _multiplier

	func get_stat_bonus(_stat: StringName) -> float:
		return _bonus
