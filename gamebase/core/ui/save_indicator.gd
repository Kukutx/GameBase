class_name SaveIndicator
extends Label

## A word on the game's HUD that the game saved itself (`AutoSave`): it shows
## for `seconds_shown`, then fades out, or goes at once with reduced motion.
## The game places it where its HUD has room, as it places a `StatusLine`. An
## autosave that fails is a toast instead, with the reason.

## How long it stays before it fades.
@export_range(0.1, 10.0, 0.1) var seconds_shown := 1.5
## How long the fade takes.
@export_range(0.0, 2.0, 0.05) var fade_seconds := 0.4

var _fade: Tween

func _ready() -> void:
	visible = false
	# It goes away while the world is paused as well.
	process_mode = Node.PROCESS_MODE_ALWAYS
	AutoSave.autosave_completed.connect(_on_autosave_completed)

## Shows that the game was saved.
func show_saved() -> void:
	if _fade != null and _fade.is_valid():
		_fade.kill()
	text = tr("Autosaved")
	modulate.a = 1.0
	visible = true
	_fade = create_tween()
	_fade.tween_interval(seconds_shown)
	if not GameSettings.reduced_motion and fade_seconds > 0.0:
		_fade.tween_property(self, "modulate:a", 0.0, fade_seconds)
	_fade.tween_callback(hide)

func _on_autosave_completed(success: bool, _reason: String) -> void:
	if success:
		show_saved()
