class_name CalendarEventVisual
extends Node2D

@export var event_id: StringName

func _ready() -> void:
	EventState.active_events_changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	visible = event_id != &"" and EventState.is_active(event_id)
