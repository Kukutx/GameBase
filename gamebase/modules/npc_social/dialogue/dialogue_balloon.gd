class_name DialogueBalloon
extends CanvasLayer

## The box a conversation shows in (`ConversationService`, through the
## `DialogueManager` addon): a panel along the bottom of the game's view,
## whatever the view's size, in the game's theme, with the speaker's name, the
## line typing out at the player's text speed
## (`GameSettings.get_seconds_per_character()`) and the responses to choose
## from. Interact, accept or a click shows the rest of a line that is still
## typing, then moves on; a line with a `time` moves on by itself. Interact
## picks the response in focus as accept does, and a response is picked once:
## the responses hide until the next line shows. A long line makes the panel
## grow upwards.
##
## The world is paused while it shows (the conversation's lock), so the
## balloon runs while paused, and it reads input only while that lock is on
## top (`InputLock.is_top()`). It frees itself when the dialogue ends.

## The actions that move a conversation on.
const ADVANCE_ACTIONS: Array[StringName] = [&"ui_accept", &"interact"]
## How long a non-inline mutation may run before the panel hides until the next
## line, so a quick one does not flicker it.
const MUTATION_HIDE_SECONDS := 0.1

@onready var _panel: Control = %Panel
@onready var _name_label: Label = %NameLabel
@onready var _line_label: DialogueLabel = %LineLabel
@onready var _responses: DialogueResponsesMenu = %Responses
@onready var _more: Control = %More

var _resource: DialogueResource
var _game_states: Array = []
var _line: DialogueLine
# The line is shown in full and a press moves on.
var _waiting := false
# Counts the lines asked for, so only the latest one asked shows.
var _asked := 0
# Ends a line with a `time`; hides the panel while a mutation runs. Children,
# so nothing waits on the balloon once it is gone.
var _line_timer := Timer.new()
var _mutation_timer := Timer.new()

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.hide()
	_responses.response_selected.connect(_on_response_selected)
	_panel.gui_input.connect(_on_panel_gui_input)
	DialogueManager.mutated.connect(_on_mutated)
	for timer: Timer in [_line_timer, _mutation_timer]:
		timer.one_shot = true
		add_child(timer)
	_line_timer.timeout.connect(func() -> void: _go_to(_line.next_id))
	_mutation_timer.timeout.connect(_panel.hide)

## Shows `resource` from `cue` on (`DialogueManager` calls it once the balloon
## is in the tree); `extra_game_states` are what its lines may read.
func start(resource: DialogueResource, cue: String = "", extra_game_states: Array = []) -> void:
	_resource = resource
	_game_states = [self] + extra_game_states
	_show_line(await resource.get_next_dialogue_line(cue, _game_states))

## The line on show, or null before the first one.
func get_line() -> DialogueLine:
	return _line

## Whether the line on show is still typing out.
func is_typing() -> bool:
	return _line_label.is_typing

## Moves the conversation on as a press of an advance action does: shows the
## rest of a line still typing, else goes to the next line of a line without
## responses that waits for the player.
func advance() -> void:
	if _line == null:
		return
	if _line_label.is_typing:
		_line_label.skip_typing()
	elif _waiting:
		_go_to(_line.next_id)

# A press anywhere but on the panel, which reads its own clicks; the focused
# response takes accept itself.
func _unhandled_input(event: InputEvent) -> void:
	if _line == null or not InputLock.is_top(self) or not _is_advance_press(event):
		return
	get_viewport().set_input_as_handled()
	var focused := get_viewport().gui_get_focus_owner()
	if _responses.visible:
		if not event is InputEventMouseButton and focused != null and focused.get_parent() == _responses and focused.has_meta("response") and not (focused is BaseButton and (focused as BaseButton).disabled):
			_responses.response_selected.emit(focused.get_meta("response"))
	else:
		advance()

func _on_panel_gui_input(event: InputEvent) -> void:
	if _line != null and InputLock.is_top(self) and event is InputEventMouseButton and _is_advance_press(event):
		_panel.accept_event()
		advance()

static func _is_advance_press(event: InputEvent) -> bool:
	var mouse := event as InputEventMouseButton
	if mouse != null:
		return mouse.pressed and mouse.button_index == MOUSE_BUTTON_LEFT
	return ADVANCE_ACTIONS.any(func(action: StringName) -> bool: return InputMap.has_action(action) and event.is_action_pressed(action))

func _show_line(line: DialogueLine) -> void:
	_line = line
	_waiting = false
	_line_timer.stop()
	_mutation_timer.stop()
	if line == null:
		queue_free()
		return
	_name_label.text = tr(line.character, &"dialogue")
	_name_label.visible = not line.character.is_empty()
	_responses.hide()
	_responses.responses = line.responses
	_more.hide()
	_line_label.seconds_per_step = GameSettings.get_seconds_per_character()
	_line_label.dialogue_line = line
	_panel.show()
	if not line.text.is_empty():
		_line_label.type_out()
		await _line_label.finished_typing
	if _line != line:
		return
	if not line.responses.is_empty():
		_responses.show()
	elif not line.time.is_empty():
		_line_timer.start(maxf(line.text.length() * 0.02 if line.time == "auto" else line.time.to_float(), 0.01))
	else:
		_waiting = true
		_more.show()

func _go_to(next_id: String) -> void:
	_waiting = false
	_responses.hide()
	_more.hide()
	_asked += 1
	var asked := _asked
	var line := await _resource.get_next_dialogue_line(next_id, _game_states)
	if asked == _asked:
		_show_line(line)

func _on_response_selected(response: DialogueResponse) -> void:
	if _line != null and _responses.visible:
		_go_to(response.next_id)

func _on_mutated(mutation: Dictionary) -> void:
	if not bool(mutation.is_inline):
		_waiting = false
		_mutation_timer.start(MUTATION_HIDE_SECONDS)
