class_name Afflictions
extends RefCounted

## The afflictions on one thing in a fight (`AfflictionData`), counted in the
## seconds of that fight: real time for a hurtbox, battle time for a unit of a
## grid or command battle. Each takes its `AfflictionData.tick_damage` every
## `AfflictionData.tick_seconds`, `AfflictionData.get_ticks()` times
## (`advance()`), and the slowest slows it while on (`get_speed_scale()`). Laid again, one lasts as long again from then, its next tick
## still due when it was, so it never stacks and quick hits never put a tick
## off. Whether a thing may take one at all (immunity, standing) is for the
## fight to say before it lays it.

const _EPSILON := 0.000001

# affliction id -> {"data": AfflictionData, "faction": StringName, "ticks":
# the ticks left, "next": seconds to the next}.
var _laid: Dictionary[StringName, Dictionary] = {}

## Lays `affliction`, from a hit of `from_faction`, to last `seconds_scale`
## times its `AfflictionData.seconds` (less on what resists it): true when it
## takes hold now, false when it was on already (it lasts anew), is null or
## would not last a tick (nothing is laid).
func lay(affliction: AfflictionData, from_faction: StringName = &"", seconds_scale := 1.0) -> bool:
	if affliction == null or affliction.get_ticks(seconds_scale) <= 0:
		return false
	var laid: Dictionary = _laid.get(affliction.id, {})
	_laid[affliction.id] = {"data": affliction, "faction": from_faction, "ticks": affliction.get_ticks(seconds_scale), "next": affliction.tick_seconds if laid.is_empty() else laid["next"]}
	return laid.is_empty()

## Whether the affliction `affliction_id` is on it.
func has(affliction_id: StringName) -> bool:
	return _laid.has(affliction_id)

## The afflictions on it, in the order laid.
func get_all() -> Array[AfflictionData]:
	var laid: Array[AfflictionData] = []
	for entry: Dictionary in _laid.values():
		laid.append(entry["data"])
	return laid

func is_empty() -> bool:
	return _laid.is_empty()

## How many afflictions are on it.
func size() -> int:
	return _laid.size()

## Lifts every affliction.
func clear() -> void:
	_laid.clear()

## Lifts the affliction `affliction_id`: true when it was on.
func lift(affliction_id: StringName) -> bool:
	return _laid.erase(affliction_id)

## The health they would all still take, every tick left of each: what lifting
## them (`clear()`, a cure) spares.
func get_damage_left() -> int:
	var left := 0
	for entry: Dictionary in _laid.values():
		left += int(entry["ticks"]) * (entry["data"] as AfflictionData).tick_damage
	return left

## How fast what they are on goes, as a share of its speed: the slowest
## `AfflictionData.speed_scale` of them, 1.0 with none that slows.
func get_speed_scale() -> float:
	var slowest := 1.0
	for entry: Dictionary in _laid.values():
		slowest = minf(slowest, (entry["data"] as AfflictionData).speed_scale)
	return slowest

## The seconds the affliction `affliction_id` lasts yet, to its last tick; 0
## when it is not on.
func get_seconds_left(affliction_id: StringName) -> float:
	var entry: Dictionary = _laid.get(affliction_id, {})
	if entry.is_empty():
		return 0.0
	var affliction: AfflictionData = entry["data"]
	return float(entry["next"]) + (int(entry["ticks"]) - 1) * affliction.tick_seconds

## The afflictions on it, in the order laid, each named in the player's
## language with the whole seconds it lasts yet, rounded up ("Burning 2s").
func describe() -> PackedStringArray:
	var told := PackedStringArray()
	for id: StringName in _laid:
		var affliction: AfflictionData = _laid[id]["data"]
		told.append(tr("%s %ds") % [tr(affliction.display_name), maxi(ceili(get_seconds_left(id) - 0.01), 1)])
	return told

## The seconds to the next tick of any of them; INF with none.
func get_next_tick() -> float:
	var soonest := INF
	for entry: Dictionary in _laid.values():
		soonest = minf(soonest, float(entry["next"]))
	return soonest

## Lets `seconds` pass: calls `on_tick` with each affliction whose tick is
## due by then and the `Damage` it does (its `tick_damage`, from the faction
## that laid it, with no push), unless it takes no health, and lifts each
## after its last. A tick that lifts the rest (`clear()`, a defeat) ends it.
func advance(seconds: float, on_tick: Callable) -> void:
	for id: StringName in _laid.keys():
		var entry: Dictionary = _laid.get(id, {})
		if entry.is_empty():
			continue
		var affliction: AfflictionData = entry["data"]
		entry["next"] = float(entry["next"]) - seconds
		while is_same(_laid.get(id), entry) and float(entry["next"]) <= _EPSILON:
			entry["next"] = float(entry["next"]) + affliction.tick_seconds
			entry["ticks"] = int(entry["ticks"]) - 1
			if int(entry["ticks"]) <= 0:
				_laid.erase(id)
			if affliction.tick_damage > 0:
				on_tick.call(affliction, Damage.new(affliction.tick_damage, entry["faction"]))
