class_name AfflictionData
extends ContentEntry

## Something a hit lays on what it hurts besides (`Damage.affliction_id`), a
## burn or a poison: for `seconds` it takes `tick_damage` of health every
## `tick_seconds`, with neither a push nor a stun, and shows in its `color` as
## it does. A hit that lays it again has it last as long again rather than
## adding another. Any kind of fight may lay it: what lays it and what keeps
## it is the fight's own, in real time the hits of creatures, hazards and the
## player's weapons that carry its `weapon_tag`.

const KIND := &"affliction"

@export var display_name := ""
@export var color := Color(1.0, 0.5, 0.18)
## How long it lasts from the hit that laid it.
@export_range(0.1, 60.0, 0.1, "suffix:s") var seconds := 3.0
## How often it takes health.
@export_range(0.1, 10.0, 0.1, "suffix:s") var tick_seconds := 1.0
@export_range(1, 999, 1) var tick_damage := 1
## The tag of the player's weapons whose hits lay it (an ember blade's burn);
## empty, none.
@export var weapon_tag := ""

## The affliction with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> AfflictionData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as AfflictionData

## The running game's afflictions, sorted by id.
static func find_all() -> Array[AfflictionData]:
	var result: Array[AfflictionData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

## How many times it takes health in all: once every `tick_seconds` while it
## lasts.
func get_ticks() -> int:
	return floori(seconds / tick_seconds + 0.000001)

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.is_empty():
		problems.append("has no display name")
	if tick_seconds > seconds:
		problems.append("takes health every %.1fs but lasts only %.1fs" % [tick_seconds, seconds])
	return problems
