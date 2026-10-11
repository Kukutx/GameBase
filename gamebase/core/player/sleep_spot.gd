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
	PlayerState.restore_full_energy()
	PlayerState.restore_full_health()
	SaveManager.save_game()
	GameEvents.toastf("Slept until %s %d", [WorldClock.get_season_name(), WorldClock.get_day_of_season()])
	_sleeping = false
