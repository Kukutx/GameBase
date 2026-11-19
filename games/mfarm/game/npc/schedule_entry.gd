class_name MFarmScheduleEntry
extends Resource

## Where a townsperson goes at a time of day, and what they do there.

@export_range(0, 23) var hour := 8
@export_range(0, 59) var minute := 0
@export var location_id: StringName
@export var cell := Vector2i.ZERO
## The animation played now and then once they arrive, from their animations
## or extra animations (`MFarmNpcData`); none
## keeps them idle.
@export var stop_animation: StringName
## Whether the player can talk to them once they arrive.
@export var interactable := true

func get_minute_of_day() -> int:
	return hour * 60 + minute
