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
	var next_day := WorldClock.day + 1
	WorldClock.set_time(next_day, 6 * 60)
	PlayerState.restore_full_energy()
	PlayerState.restore_full_health()
	SaveManager.save_game()
	GameEvents.toastf("Slept until %s %d", [WorldClock.get_season_name(), WorldClock.get_day_of_season()])
	_sleeping = false
