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
