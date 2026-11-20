class_name GameStatsService
extends Node

## Numbers the game's systems read and other systems change: the energy a
## tool costs, how long a fish takes to bite, how hard an attack hits.
##
## The core registers the stats it reads (`TopDownPlayer.MOVE_SPEED_STAT`), and
## a module or the game each stat it reads (`register_stat()`), in its
## `GameModule.install()`; content that changes a stat (a food buff, a
## skill perk) may name only a registered one. Whatever changes stats
## registers as a source (`register_source()`): an object with
## `get_stat_multiplier(stat) -> float` and `get_stat_bonus(stat) -> float`. A
## system reads a stat here, never from a source: a value becomes
## `(base + get_bonus(stat)) * get_multiplier(stat)` (`apply()`). A source
## tells when its changes changed (`notify_changed()`: a boon taken, an
## upgrade bought, a buff run out), and `changed` tells whatever keeps a value
## it read from a stat (a vital's maximum) to read it again.
##
## A stat the player should know of has a name (`register_stat()`'s
## `display_name`), so content's changes read themselves out
## (`describe_changes()`: "Attack +10%", "Max health +15") and the numbers the
## player is shown are always the ones the game uses.

## The stats may read otherwise now: a source was added or removed, or its
## changes changed.
signal changed

# Each registered stat and the name the player knows it by ("" none), in the
# order they were registered.
var _stats: Dictionary[StringName, String] = {}
var _sources: Array[Object] = []

func _init() -> void:
	# The stats the core's own systems read.
	register_stat(TopDownPlayer.MOVE_SPEED_STAT, "Move speed")

## Declares that an installed module or the game reads `stat`, which the
## player knows as `display_name` (a translation key, the module's or the
## game's catalog translating it); empty: the player is never told of it.
## Registering a stat again keeps its name unless the new call names it.
func register_stat(stat: StringName, display_name := "") -> void:
	if not _stats.has(stat) or not display_name.is_empty():
		_stats[stat] = display_name

func has_stat(stat: StringName) -> bool:
	return _stats.has(stat)

## Adds a source of stat changes (see the class description).
func register_source(source: Object) -> void:
	if not source.has_method(&"get_stat_multiplier") or not source.has_method(&"get_stat_bonus"):
		push_error("GameStats: %s has no get_stat_multiplier() and get_stat_bonus()" % source)
		return
	if not _sources.has(source):
		_sources.append(source)
		changed.emit()

## Removes a source of stat changes, its changes with it.
func unregister_source(source: Object) -> void:
	if _sources.has(source):
		_sources.erase(source)
		changed.emit()

## Tells that a source's changes changed (`changed`); each source calls it
## when they do.
func notify_changed() -> void:
	changed.emit()

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

## The name the player knows `stat` by, translated; "" for a stat without one.
func get_stat_name(stat: StringName) -> String:
	var key: String = _stats.get(stat, "")
	return tr(key) if not key.is_empty() else ""

## The changes `multipliers` and `bonuses` (stat -> factor, stat -> amount)
## make, as the player reads them: a line for each, in the order the stats
## were registered, a bonus as a signed amount ("Max health +15") and a
## multiplier as a signed percent ("Attack +10%", "Damage Taken -20%"). A stat
## without a name, and a change that changes nothing, are left out.
func describe_changes(multipliers: Dictionary, bonuses: Dictionary) -> PackedStringArray:
	var lines := PackedStringArray()
	for stat: StringName in _stats:
		var stat_name := get_stat_name(stat)
		if stat_name.is_empty():
			continue
		var bonus := float(bonuses.get(stat, 0.0))
		if absf(bonus) >= 0.05:
			lines.append("%s %s" % [stat_name, _signed(bonus)])
		var percent := roundf((float(multipliers.get(stat, 1.0)) - 1.0) * 100.0)
		if percent != 0.0:
			lines.append("%s %s%%" % [stat_name, _signed(percent)])
	return lines

## What every source makes of the stats now, read as `describe_changes()`
## reads content's: each named stat's bonuses summed and multipliers
## multiplied ("Attack +38%" for two boons of +10% and +25%).
func describe_current() -> PackedStringArray:
	var multipliers := {}
	var bonuses := {}
	for stat: StringName in _stats:
		multipliers[stat] = get_multiplier(stat)
		bonuses[stat] = get_bonus(stat)
	return describe_changes(multipliers, bonuses)

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

# `value` with its sign, whole when it is whole ("+15", "-0.5").
static func _signed(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "%+d" % roundi(value)
	return "%+.1f" % value
