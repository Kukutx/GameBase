class_name LateNightService
extends Node

## Sends a player who stays up too late home: at the game's late night minute
## (`LifesimSettings.late_night_minute`), a player still in the world passes
## out (`GameSession.pass_out()`) and wakes at home the next morning with what
## a night's sleep refills full, but only part of their energy
## (`LifesimSettings.late_night_energy_percent`). A wait
## (`GameClock.advance_until()`) ends at that minute too, while a player is up.

## The cause the player passes out with (`GameSession.passing_out`).
const CAUSE := &"late_night"

func _ready() -> void:
	WorldClock.minute_changed.connect(_on_minute_changed)
	WorldClock.register_wait_stop(_is_wait_stop)

func _is_wait_stop(_day: int, minute_of_day: int) -> bool:
	return minute_of_day == LifesimSettings.current().late_night_minute and _is_player_up()

func _on_minute_changed(day: int, minute_of_day: int) -> void:
	if minute_of_day == LifesimSettings.current().late_night_minute and not GameSession.is_passing_out() and _is_player_up():
		_pass_out.call_deferred(day)

func _pass_out(day: int) -> void:
	var settings := LifesimSettings.current()
	var calendar := GameCalendar.current()
	# The clock may have run a few minutes on in the same frame (short game
	# minutes, a long frame, an action that passes time); the player still
	# passes out unless it was moved past the morning (they slept).
	var late_at := GameClock.absolute_minute(day, settings.late_night_minute)
	var wake_at := GameClock.absolute_minute(calendar.get_wake_day(day, settings.late_night_minute), calendar.wake_minute)
	var now := WorldClock.get_absolute_minute()
	if now < late_at or now >= wake_at or GameSession.is_passing_out() or not _is_player_up():
		return
	var woke_at_home := await GameSession.pass_out(CAUSE, _recover, day, settings.late_night_minute)
	LifesimEvents.stayed_up_late.emit(woke_at_home)
	GameEvents.toast("You stayed up too late and woke at home with reduced energy" if woke_at_home else "You stayed up too late and recovered with reduced energy")

func _recover() -> void:
	var settings := LifesimSettings.current()
	Vitals.refill_after_sleep()
	var energy := settings.energy_vital_id
	if Vitals.has_vital(energy):
		Vitals.set_value(energy, maxi(Vitals.get_maximum(energy) * settings.late_night_energy_percent / 100, 1))

func _is_player_up() -> bool:
	return get_tree().get_first_node_in_group(&"player") != null
