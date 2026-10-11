class_name LifesimRules
extends RefCounted

## Condition and action keys of the life-sim module (see `GameRulesService`).

static func register(rules: GameRulesService) -> void:
	rules.register_condition(&"EVENT_ACTIVE", _event_active, 1, 1, [CalendarEventData.KIND])

## EVENT_ACTIVE <calendar_event>: the calendar event is on at the day and
## minute asked about (now, unless the context names them).
static func _event_active(args: PackedStringArray, context: Dictionary) -> bool:
	var event := CalendarEventData.find(StringName(args[0]))
	return event != null and event.is_active(GameRulesService.context_day(context), GameRulesService.context_minute(context))
