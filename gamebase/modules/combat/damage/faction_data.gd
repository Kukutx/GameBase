class_name FactionData
extends ContentEntry

## A side in a fight. Any two different factions are enemies, unless one lists
## the other among its `allies`; a faction never hurts itself, and damage of no
## faction (a trap, a fall) hurts every side. A faction needs an entry only to
## have allies (a pet on the player's side): an id alone names a side.

const KIND := &"faction"
## The player's side.
const PLAYER := &"player"
## The side of the creatures that attack the player (`EnemyData.faction_id`).
const MONSTERS := &"monsters"

## The factions this one never hurts and is never hurt by.
@export var allies: Array[StringName] = []

## The faction with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> FactionData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as FactionData

## Whether damage of faction `attacker` hurts faction `target`.
static func are_hostile(attacker: StringName, target: StringName) -> bool:
	if attacker == &"" or target == &"":
		return true
	if attacker == target:
		return false
	return not _allied(attacker, target) and not _allied(target, attacker)

static func _allied(faction_id: StringName, other_id: StringName) -> bool:
	var faction := find(faction_id)
	return faction != null and faction.allies.has(other_id)

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	for ally: StringName in allies:
		if ally == &"":
			problems.append("lists an empty faction among its allies")
		elif ally == id:
			problems.append("lists itself among its allies")
	return problems
