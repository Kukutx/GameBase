class_name TacticsSettings
extends ModuleSettings

## What a game sets for its grid battles (`GameDefinition.module_settings`).

## Whether time goes on while the player picks a unit's commands (active
## time: the foes keep acting) or stands still until they are given (wait).
@export var time_flows_while_choosing := false
## How fast battle time passes, against real time.
@export_range(0.25, 4.0, 0.05) var battle_speed := 1.0

## The running game's grid battle settings.
static func current() -> TacticsSettings:
	return GameDefinition.current().get_settings(TacticsSettings) as TacticsSettings

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if battle_speed <= 0.0:
		problems.append("battle speed %s is not above 0" % battle_speed)
	return problems
