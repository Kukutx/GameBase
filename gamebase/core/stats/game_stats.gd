class_name GameStatsService
extends Node

## Numbers the game's systems read and other systems change: the energy a
## tool costs, how long a fish takes to bite, how hard an attack hits.
##
## A module or the game registers each stat it reads (`register_stat()`), in
## its `GameModule.install()`; content that changes a stat (a food buff, a
## skill perk) may name only a registered one. Whatever changes stats
## registers as a source (`register_source()`): an object with
## `get_stat_multiplier(stat) -> float` and `get_stat_bonus(stat) -> float`. A
## system reads a stat here, never from a source: a value becomes
## `(base + get_bonus(stat)) * get_multiplier(stat)` (`apply()`).

var _stats: Dictionary[StringName, bool] = {}
var _sources: Array[Object] = []

## Declares that an installed module or the game reads `stat`.
func register_stat(stat: StringName) -> void:
	_stats[stat] = true

func has_stat(stat: StringName) -> bool:
	return _stats.has(stat)

## Adds a source of stat changes (see the class description).
func register_source(source: Object) -> void:
	if not source.has_method(&"get_stat_multiplier") or not source.has_method(&"get_stat_bonus"):
		push_error("GameStats: %s has no get_stat_multiplier() and get_stat_bonus()" % source)
		return
	if not _sources.has(source):
		_sources.append(source)

## The product of every source's multiplier of `stat`; 1.0 when none changes it.
func get_multiplier(stat: StringName) -> float:
	var result := 1.0
	for source: Object in _sources:
		result *= float(source.call(&"get_stat_multiplier", stat))
	return result

## The sum of every source's bonus to `stat`; 0.0 when none changes it.
func get_bonus(stat: StringName) -> float:
	var result := 0.0
	for source: Object in _sources:
		result += float(source.call(&"get_stat_bonus", stat))
	return result

## `base` changed by every source: the bonuses added, then the multipliers.
func apply(stat: StringName, base: float) -> float:
	return (base + get_bonus(stat)) * get_multiplier(stat)

## What is wrong with stat changes content declares (a food buff, a skill
## perk), each problem a phrase: a stat nothing registered, or a multiplier
## that is not positive.
func find_change_problems(multipliers: Dictionary[StringName, float], bonuses: Dictionary[StringName, float]) -> PackedStringArray:
	var problems := PackedStringArray()
	for stat: StringName in multipliers:
		if not has_stat(stat):
			problems.append("changes stat '%s', which no installed module or the game reads" % stat)
		elif multipliers[stat] <= 0.0:
			problems.append("has a non-positive multiplier of '%s'" % stat)
	for stat: StringName in bonuses:
		if not has_stat(stat):
			problems.append("changes stat '%s', which no installed module or the game reads" % stat)
	return problems
