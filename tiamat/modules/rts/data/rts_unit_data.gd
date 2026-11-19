class_name RtsUnitData
extends ContentEntry

## A kind of unit that fights in command battles (`RtsMapData.placements`): a
## footman, a bowman, a raider. It walks the field at `move_speed`, attacks a
## foe at most `attack_range` away from its edge once every `attack_cooldown`
## seconds, and goes after foes it sees (`sight_range`) when it has no order
## that keeps it from them (`RtsBattle`). Distances are in pixels of the field.

const KIND := &"rts_unit"

@export var display_name := ""
## What the field shows of it; none: a disc of `color` with its name's initial.
@export var texture: Texture2D
@export var color := Color(0.55, 0.6, 0.7)
@export_range(1, 9999) var max_health := 30
## The health an attack takes, less the target's `armor`, never below 1.
@export_range(1, 999) var damage := 5
@export_range(0, 999) var armor := 0
## How far from its edge to a foe's edge it attacks: a few pixels for a blade,
## many for a bow.
@export_range(1.0, 400.0, 0.5) var attack_range := 4.0
## The seconds between its attacks.
@export_range(0.1, 10.0, 0.05) var attack_cooldown := 1.0
## How fast it walks, in pixels a second.
@export_range(1.0, 400.0, 0.5) var move_speed := 30.0
## How far from its edge it notices a foe and goes after it.
@export_range(1.0, 600.0, 0.5) var sight_range := 80.0
## The size of its round body, which other units keep out of.
@export_range(2.0, 32.0, 0.5) var radius := 5.0

## The unit with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> RtsUnitData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as RtsUnitData

## The running game's units, sorted by id.
static func find_all() -> Array[RtsUnitData]:
	var result: Array[RtsUnitData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.is_empty():
		problems.append("has no display name")
	if sight_range < attack_range:
		problems.append("sees %s, less far than it attacks, %s" % [sight_range, attack_range])
	return problems
