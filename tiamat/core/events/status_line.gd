class_name StatusLine
extends Label

## A line of short messages for the player: the toasts `GameEvents` sends, the
## hints it sends (`HintData`) on a line that shows them, what a save or a load
## says (`SaveManager`), and whatever the game shows with `show_message()`.
## Each message stays `seconds_per_message`, a hint `seconds_per_hint`, as it
## asks to be read; one that arrives while another is shown waits its turn, so
## messages sent together, such as a harvest and the achievement it unlocked,
## are each read. A hint names its controls anew when the player picks up
## another device or rebinds them, shown or waiting, so it never names the
## keyboard's keys to a player on a gamepad or a touchscreen.

## How long a message stays.
@export_range(0.1, 30.0, 0.1) var seconds_per_message := 2.5
## How long a hint stays.
@export_range(0.1, 30.0, 0.1) var seconds_per_hint := 6.0
## How many messages wait at most; the oldest waiting one gives way.
@export_range(1, 20) var max_waiting := 3
## Whether it shows the toasts `GameEvents` sends.
@export var shows_toasts := true
## Whether it shows the hints `GameEvents` sends.
@export var shows_hints := false
## Whether it shows what a save or a load the player asked for says.
@export var shows_saves := true

var _waiting: PackedStringArray = []
# How long each waiting message stays.
var _waiting_seconds: PackedFloat64Array = []
# The hint each waiting message is, or &"" for a message that is none.
var _waiting_hints: Array[StringName] = []
var _seconds_left := 0.0
# The hint on show, or &"".
var _hint_id := &""

func _ready() -> void:
	text = ""
	if shows_toasts:
		GameEvents.toast_requested.connect(show_message)
	if shows_hints:
		GameEvents.hint_requested.connect(_show_hint)
		InputPrompts.input_method_changed.connect(_rename_hint.unbind(1))
		InputPrompts.prompts_changed.connect(_rename_hint)
		GameSettings.controls_changed.connect(_rename_hint)
	if shows_saves:
		SaveManager.save_completed.connect(_show_save_message)
		SaveManager.load_completed.connect(_show_save_message)

func _process(delta: float) -> void:
	if _seconds_left <= 0.0:
		return
	_seconds_left -= delta
	if _seconds_left > 0.0:
		return
	if _waiting.is_empty():
		text = ""
		_hint_id = &""
	else:
		_show(_hint_message(_waiting_hints[0], _waiting[0]), _waiting_seconds[0], _waiting_hints[0])
		_remove_waiting(0)

## Shows `message` (already translated) now, or after the messages before it,
## for `seconds` (`seconds_per_message` when 0). The message on show, said
## again, stays for a while longer instead.
func show_message(message: String, seconds := 0.0) -> void:
	_add(message, seconds, &"")

## The messages waiting their turn, in order.
func get_waiting() -> PackedStringArray:
	return _waiting.duplicate()

func _show_save_message(_success: bool, message: String) -> void:
	show_message(message)

func _show_hint(message: String, hint_id: StringName) -> void:
	_add(message, seconds_per_hint, hint_id)

func _add(message: String, seconds: float, hint_id: StringName) -> void:
	if message.is_empty():
		return
	if seconds <= 0.0:
		seconds = seconds_per_message
	if _seconds_left <= 0.0 or (message == text and _waiting.is_empty()):
		_show(message, maxf(seconds, _seconds_left) if message == text else seconds, hint_id)
		return
	if not _waiting.is_empty() and message == _waiting[-1]:
		return
	_waiting.append(message)
	_waiting_seconds.append(seconds)
	_waiting_hints.append(hint_id)
	if _waiting.size() > max_waiting:
		_remove_waiting(0)

func _remove_waiting(index: int) -> void:
	_waiting.remove_at(index)
	_waiting_seconds.remove_at(index)
	_waiting_hints.remove_at(index)

func _show(message: String, seconds: float, hint_id := &"") -> void:
	text = message
	_seconds_left = seconds
	_hint_id = hint_id

# The hint on show names its controls as the device in use performs them; a
# waiting one does when its turn comes.
func _rename_hint() -> void:
	if _seconds_left > 0.0 and not _hint_id.is_empty():
		text = _hint_message(_hint_id, text)

# The text of hint `hint_id` now, or `message` for a message that is no hint
# of the running game.
func _hint_message(hint_id: StringName, message: String) -> String:
	if hint_id.is_empty():
		return message
	var hint := HintData.find(hint_id)
	return hint.get_message() if hint != null else message
