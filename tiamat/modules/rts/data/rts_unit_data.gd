class_name RtsUnitData
extends ContentEntry

## A kind of unit that fights in command battles (`RtsMapData.placements`): a
## footman, a bowman, a raider. It walks the field at `move_speed`, attacks a
## foe at most `attack_range` away from its edge once every `attack_cooldown`
## seconds, and goes after foes it sees (`sight_range`) when it has no order
## that keeps it from them (`RtsBattle`). A healer (`heal`) mends its side
## instead of fighting. A unit may be strong against some kinds
## (`strong_against`): it hits them harder and goes after them first. Its
## attacks may lay an affliction (`affliction_id`), some afflictions never
## take hold of it (`immune_to`), and a healer may lift them (`cures`).
## Distances are in pixels of the field.

const KIND := &"rts_unit"

## The name the player reads.
@export var display_name := ""
## What the field shows of it; none: a disc of `color` with its name's initial.
@export var texture: Texture2D
@export var color := Color(0.55, 0.6, 0.7)
## Its health as it comes on the field, and the most mending gives back.
@export_range(1, 9999) var max_health := 30
## The health an attack takes, less the target's `armor`, never below 1.
@export_range(1, 999) var damage := 5
## What it takes off each attack on it.
@export_range(0, 999) var armor := 0
## How far from its edge to a foe's edge it attacks: a few pixels for a blade,
## many for a bow.
@export_range(1.0, 400.0, 0.5) var attack_range := 4.0
## The health it mends instead of attacking: a healer goes after the most
## hurt unit it sees of a side it does not fight, itself aside, and mends it
## from `attack_range` once every `attack_cooldown`, and never strikes a foe.
## 0: it fights.
@export_range(0, 999) var heal := 0
## Whether its mending also lifts every affliction on the friend it mends
## (`RtsUnit.afflictions`): a field medic who puts out a burn. Only a healer
## cures.
@export var cures := false
## The seconds between its attacks.
@export_range(0.1, 10.0, 0.05) var attack_cooldown := 1.0
## How fast it walks, in pixels a second.
@export_range(1.0, 400.0, 0.5) var move_speed := 30.0
## How far from its edge it notices a foe and goes after it.
@export_range(1.0, 600.0, 0.5) var sight_range := 80.0
## The size of its round body, which other units keep out of.
@export_range(2.0, 32.0, 0.5) var radius := 5.0
## The kinds of unit (`RtsUnitData` ids) its attacks hit `strong_multiplier`
## times as hard, and which it goes after before the rest it sees: a rider
## running down slingers, a spear holding off a brute.
@export var strong_against: Array[StringName] = []
@export_range(1.0, 4.0, 0.25) var strong_multiplier := 2.0
## The affliction (`AfflictionData`) its attacks lay on the foes they leave
## standing, a burn that takes more health in battle time; empty, none.
@export var affliction_id: StringName
## The afflictions (`AfflictionData` ids) that never take hold of it: a
## fire-born brute that never burns.
@export var immune_to: Array[StringName] = []

## Whether it mends its side instead of fighting (`heal`).
func heals() -> bool:
	return heal > 0

## Whether it is strong against units of `other` (`strong_against`).
func is_strong_against(other: RtsUnitData) -> bool:
	return other != null and strong_against.has(other.id)

## The health an attack of it takes from a unit of `target`: its damage,
## `strong_multiplier` times as much against a kind it is strong against,
## less the target's armor, never below 1.
func damage_to(target: RtsUnitData) -> int:
	var dealt := damage * (strong_multiplier if is_strong_against(target) else 1.0)
	return maxi(roundi(dealt) - target.armor, 1)

## The affliction its attacks lay (`affliction_id`), or null.
func get_affliction() -> AfflictionData:
	return AfflictionData.find(affliction_id) if affliction_id != &"" else null

## The unit with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> RtsUnitData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as RtsUnitData

## The running game's units, sorted by id.
static func find_all() -> Array[RtsUnitData]:
	var result: Array[RtsUnitData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	for kind: StringName in strong_against:
		if not registry.has_entry(KIND, kind):
			problems.append("is strong against unknown unit '%s'" % kind)
	if heals() and not strong_against.is_empty():
		problems.append("heals, yet is strong against units it never strikes")
	if affliction_id != &"" and not registry.has_entry(AfflictionData.KIND, affliction_id):
		problems.append("lays unknown affliction '%s'" % affliction_id)
	if heals() and affliction_id != &"":
		problems.append("heals, yet lays an affliction with the blows it never strikes")
	if cures and not heals():
		problems.append("cures, yet never mends")
	for affliction: StringName in immune_to:
		if not registry.has_entry(AfflictionData.KIND, affliction):
			problems.append("is immune to unknown affliction '%s'" % affliction)
	if display_name.is_empty():
		problems.append("has no display name")
	if sight_range < attack_range:
		problems.append("sees %s, less far than it attacks, %s" % [sight_range, attack_range])
	return problems
