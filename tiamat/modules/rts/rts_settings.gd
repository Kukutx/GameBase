class_name RtsSettings
extends ModuleSettings

## What a game sets for its command battles (`GameDefinition.module_settings`).

## How fast battle time passes, against real time.
@export_range(0.25, 4.0, 0.05) var battle_speed := 1.0
## How fast the cursor of the keys and the gamepad crosses the field, in
## pixels of the field a second.
@export_range(20.0, 1000.0, 5.0) var cursor_speed := 160.0

## The running game's command battle settings.
static func current() -> RtsSettings:
	return GameDefinition.current().get_settings(RtsSettings) as RtsSettings

func find_problems(_registry: ContentRegistry) -> PackedStringArray:
	var problems := PackedStringArray()
	if battle_speed <= 0.0:
		problems.append("battle speed %s is not above 0" % battle_speed)
	if cursor_speed <= 0.0:
		problems.append("cursor speed %s is not above 0" % cursor_speed)
	return problems
