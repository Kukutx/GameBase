extends Node

## The old game's two time keys, kept for testing in debug builds only (an
## exported release has none): holding T runs the clock a minute a frame, G
## moves on a whole day, so crops grow and the land changes.

const MINUTES_PER_DAY := 24 * 60

func _ready() -> void:
	if not OS.is_debug_build():
		queue_free()
		return
	set_process(false)

func _unhandled_key_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null or key.echo or InputLock.is_locked():
		return
	if key.physical_keycode == KEY_T:
		set_process(key.pressed)
	elif key.physical_keycode == KEY_G and key.pressed:
		WorldClock.advance_minutes(MINUTES_PER_DAY)

func _process(_delta: float) -> void:
	if Input.is_physical_key_pressed(KEY_T) and not InputLock.is_locked():
		WorldClock.advance_minutes(1)
	else:
		set_process(false)
