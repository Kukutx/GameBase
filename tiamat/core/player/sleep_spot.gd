class_name SleepSpot
extends Node2D

@onready var interactable: Interactable = $Interactable

var _sleeping := false

func _ready() -> void:
	interactable.interacted.connect(_on_interacted)

func _on_interacted(_actor: Node) -> void:
	if _sleeping:
		return
	_sleeping = true
	var calendar := GameCalendar.current()
	WorldClock.set_time(calendar.get_wake_day(WorldClock.day, WorldClock.minute_of_day), calendar.wake_minute)
	Vitals.refill_after_sleep()
	SaveManager.save_game()
	GameEvents.toastf("Slept until %s", [calendar.get_date_text(WorldClock.day)])
	_sleeping = false
