class_name FarmClockLine
extends PlaceLine

## The date and the time, the day's weather and the events the town holds
## today where the player stands (`EventState`).

func _watch() -> void:
	super()
	watch(EventState.active_events_changed)

func _get_parts() -> PackedStringArray:
	var parts := super()
	var location := WorldLocationData.find_current(get_tree())
	parts.append(EventState.get_summary(location.id if location != null else &""))
	return parts
