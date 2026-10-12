class_name LifesimSettings
extends ModuleSettings

## What a game sets for the life-sim module (`GameDefinition.module_settings`):
## the vital its work spends and how late the player may stay up.

## The vital that farming, mining and fishing spend (`VitalData`); empty: the
## work is free.
@export var energy_vital_id: StringName
## The minute a player who is still up passes out and wakes at home the next
## morning (`LateNight`); -1 never.
@export_range(-1, 1439) var late_night_minute := 2 * 60
## How much of their energy vital, in percent of its maximum, a player who
## stayed up too late wakes with.
@export_range(1, 100) var late_night_energy_percent := 50

## The running game's life-sim settings.
static func current() -> LifesimSettings:
	return GameDefinition.current().get_settings(LifesimSettings) as LifesimSettings

## Spends `amount` of the energy vital on work: false, and nothing spent, when
## there is not that much, which the player is told unless `tell` is false.
static func spend_energy(amount: int, tell := true) -> bool:
	var energy := current().energy_vital_id
	return Vitals.try_spend(energy, amount) if tell else Vitals.spend(energy, amount)

## Gives back `amount` of the energy vital, spent on work that did not happen.
static func refund_energy(amount: int) -> void:
	Vitals.restore(current().energy_vital_id, amount)

func find_problems(registry: ContentRegistry) -> PackedStringArray:
	var problems := VitalData.find_reference_problems(registry, "energy vital", energy_vital_id)
	if late_night_minute < -1 or late_night_minute >= GameClock.MINUTES_PER_DAY:
		problems.append("late night minute %d is neither -1 nor a minute of the day" % late_night_minute)
	elif late_night_minute == GameDefinition.current().get_calendar().wake_minute:
		problems.append("late night sends the player home at the minute they wake")
	if late_night_energy_percent < 1 or late_night_energy_percent > 100:
		problems.append("late night energy %d is not a percentage from 1 to 100" % late_night_energy_percent)
	return problems
