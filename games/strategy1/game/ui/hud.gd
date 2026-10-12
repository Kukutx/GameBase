extends CanvasLayer

## What the player sees over the world: where they are and the time, the
## status messages (the toasts and what a save or a load says), a word when
## the game saved itself, what is near to use and the controls. It holds the
## pause menu. Add the game's own lines here (health, money, a hotbar), as
## games/dungeon1/game/ui/hud.gd does.

@onready var place_label: Label = $Place
@onready var status_line: StatusLine = $Status
@onready var controls_label: Label = $Controls

func _ready() -> void:
	WorldClock.minute_changed.connect(_on_minute_changed)
	SaveManager.save_completed.connect(_on_save_completed)
	SaveManager.load_completed.connect(_on_load_completed)
	InputPrompts.input_method_changed.connect(_on_input_method_changed)
	GameSettings.controls_changed.connect(_refresh_controls)
	GameSettings.locale_changed.connect(_on_locale_changed)
	# The place is read from the current scene, which is set once the scene is in.
	_refresh_all.call_deferred()

## Shows `message` for a few seconds, after the messages before it.
func show_status(message: String) -> void:
	status_line.show_message(message)

func _refresh_all() -> void:
	_refresh_place()
	_refresh_controls()

func _refresh_place() -> void:
	if not is_inside_tree():
		return
	var location := WorldLocationData.find_current(get_tree())
	var place := tr(location.display_name) if location != null else ""
	place_label.text = "%s · %s" % [place, WorldClock.get_calendar_text()]

func _refresh_controls() -> void:
	controls_label.text = tr("%s move · %s use · %s save · %s load") % [
		InputPrompts.get_move_prompt(),
		InputPrompts.get_action_prompt(&"interact"),
		InputPrompts.get_action_prompt(&"quick_save"),
		InputPrompts.get_action_prompt(&"quick_load"),
	]

func _on_minute_changed(_day: int, _minute_of_day: int) -> void:
	_refresh_place()

func _on_save_completed(_success: bool, message: String) -> void:
	show_status(message)

func _on_load_completed(_success: bool, message: String) -> void:
	show_status(message)

func _on_input_method_changed(_using_gamepad: bool) -> void:
	_refresh_controls()

func _on_locale_changed(_locale: String) -> void:
	_refresh_all()
