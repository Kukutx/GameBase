class_name AfflictionData
extends ContentEntry

## Something a hit lays on what it hurts besides (`Damage.affliction_id`), a
## burn, a poison or a sticky slime: for `seconds` it takes `tick_damage` of
## health every `tick_seconds`, with neither a push nor a stun, and shows in
## its `color` as it does, and it may slow what it is on (`speed_scale`). A
## hit that lays it again has it last as long again rather than adding
## another. Any kind of fight may lay it: what lays it and what keeps
## it is the fight's own, in real time the hits of creatures, hazards and the
## player's weapons that carry its `weapon_tag`, or any of the player's hits
## by the chance its `chance_stat` gives. What lifts it is the fight's too: in
## real time, the items tagged its `cure_tag` the player eats or drinks.

const KIND := &"affliction"

@export var display_name := ""
@export var color := Color(1.0, 0.5, 0.18)
## How long it lasts from the hit that laid it.
@export_range(0.1, 60.0, 0.1, "suffix:s") var seconds := 3.0
## How often it takes health.
@export_range(0.1, 10.0, 0.1, "suffix:s") var tick_seconds := 1.0
## The health each tick takes; 0, none: one that only slows.
@export_range(0, 999, 1) var tick_damage := 1
## How fast what it is on goes while it lasts, as a share of its speed: its
## steps in real time and in a command battle, its time gauge in a grid
## battle. 1: as fast as ever; of two that slow, the slower counts.
@export_range(0.1, 1.0, 0.05) var speed_scale := 1.0
## The tag of the player's weapons whose hits lay it (an ember blade's burn);
## empty, none.
@export var weapon_tag := ""
## The stat (`GameStats`, which the game registers) that is the chance, in
## percent, that a hit of the player's lays it whatever their weapon (Ember
## Depths' Kindling boon, a blow in four burning); empty, none.
@export var chance_stat: StringName
## The tag of the items whose eating or drinking lifts it from the player (an
## antidote's poison); empty, none.
@export var cure_tag := ""

## The affliction with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> AfflictionData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as AfflictionData

## The running game's afflictions, sorted by id.
static func find_all() -> Array[AfflictionData]:
	var result: Array[AfflictionData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

## Whether it slows what it is on (`speed_scale`).
func slows() -> bool:
	return speed_scale < 1.0

## How many times it takes health in all: once every `tick_seconds` while it
## lasts, `seconds_scale` times its `seconds` (shorter on what resists it).
func get_ticks(seconds_scale := 1.0) -> int:
	return floori(seconds * seconds_scale / tick_seconds + 0.000001)

## Whether a hit of the player's lays it by chance now: a roll under its
## `chance_stat`, every hit from 100 on and none at 0.
func rolls_chance() -> bool:
	if chance_stat == &"":
		return false
	var chance := GameStats.apply(chance_stat, 0.0)
	return chance >= 100.0 or (chance > 0.0 and randf() * 100.0 < chance)

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.is_empty():
		problems.append("has no display name")
	if tick_seconds > seconds:
		problems.append("takes health every %.1fs but lasts only %.1fs" % [tick_seconds, seconds])
	if tick_damage <= 0 and not slows():
		problems.append("takes no health and slows nothing")
	if chance_stat != &"" and not GameStats.has_stat(chance_stat):
		problems.append("is laid by the chance of stat '%s', which no installed module or the game reads" % chance_stat)
	return problems
