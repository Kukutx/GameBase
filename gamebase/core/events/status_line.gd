class_name StatusLine
extends Label

## A line of short messages for the player: the toasts `GameEvents` sends and
## whatever the game shows with `show_message()`. Each message stays
## `seconds_per_message`; one that arrives while another is shown waits its
## turn, so messages sent together, such as a harvest and the achievement it
## unlocked, are each read.

## How long a message stays.
@export_range(0.1, 30.0, 0.1) var seconds_per_message := 2.5
## How many messages wait at most; the oldest waiting one gives way.
@export_range(1, 20) var max_waiting := 3
## Whether it shows the toasts `GameEvents` sends.
@export var shows_toasts := true

var _waiting: PackedStringArray = []
var _seconds_left := 0.0

func _ready() -> void:
	text = ""
	if shows_toasts:
		GameEvents.toast_requested.connect(show_message)

func _process(delta: float) -> void:
	if _seconds_left <= 0.0:
		return
	_seconds_left -= delta
	if _seconds_left > 0.0:
		return
	if _waiting.is_empty():
		text = ""
	else:
		_show(_waiting[0])
		_waiting.remove_at(0)

## Shows `message` (already translated) now, or after the messages before it.
## The message on show, said again, stays for a while longer instead.
func show_message(message: String) -> void:
	if message.is_empty():
		return
	if _seconds_left <= 0.0 or (message == text and _waiting.is_empty()):
		_show(message)
		return
	if not _waiting.is_empty() and message == _waiting[-1]:
		return
	_waiting.append(message)
	if _waiting.size() > max_waiting:
		_waiting.remove_at(0)

## The messages waiting their turn, in order.
func get_waiting() -> PackedStringArray:
	return _waiting.duplicate()

func _show(message: String) -> void:
	text = message
	_seconds_left = seconds_per_message
