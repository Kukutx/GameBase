class_name VitalData
extends ContentEntry

## Something of the player's the game counts down and refills (`Vitals`):
## health, energy, mana, hunger. Work and attacks spend it, food and sleep
## restore it, enemies drain it; the module that owns a use names the vital in
## its settings (`CombatSettings.health_vital_id`).

const KIND := &"vital"

## The name the player reads: Health, Energy.
@export var display_name: String
## How much a full one holds at the start of a game.
@export_range(1, 9999, 1) var maximum := 100
## Whether a night's sleep fills it again (`SleepSpot`).
@export var refill_on_sleep := true
## A stat its maximum follows (`GameStats`, registered by a module or the
## game: combat's `max_health`): the stat's bonuses add to the maximum and its
## multipliers scale it, so a boon or a lasting upgrade raises it. None
## follows none.
@export var maximum_stat: StringName

## The vital with `entry_id` in the running game's content, or null.
static func find(entry_id: StringName) -> VitalData:
	return ContentRegistry.active.get_entry(KIND, entry_id) as VitalData

## The running game's vitals, sorted by id.
static func find_all() -> Array[VitalData]:
	var result: Array[VitalData] = []
	result.assign(ContentRegistry.active.get_entries(KIND))
	return result

## Problems with `vital_id` as a setting that names a vital: an id that is
## none of `registry`'s vitals (empty names none and is fine).
static func find_reference_problems(registry: ContentRegistry, setting: String, vital_id: StringName) -> PackedStringArray:
	if vital_id == &"" or registry.has_entry(KIND, vital_id):
		return PackedStringArray()
	return PackedStringArray(["%s '%s' is no vital" % [setting, vital_id]])

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if display_name.strip_edges().is_empty():
		problems.append("has no display name")
	if maximum < 1:
		problems.append("maximum %d is not at least 1" % maximum)
	if maximum_stat != &"" and not GameStats.has_stat(maximum_stat):
		problems.append("follows stat '%s', which no installed module or the game reads" % maximum_stat)
	return problems
