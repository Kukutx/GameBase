class_name MFarmDialogueBox
extends Control

## A conversation, line by line, as the old game showed it: the talk box low
## in the middle of the screen, the speaker's face and name on their side,
## the words typed out over a second, then a note to press Space. Space (or
## a click) finishes the line being typed, or goes on to the next. The world
## stands still until the last line is read.

signal finished

const LOCK := &"mfarm_dialogue"
const TYPE_SECONDS := 1.0
const PANEL_SIZE := Vector2(190, 64)
const TEXT_COLOR := Color(0.196, 0.196, 0.196)

var _text: Label
var _faces: Array[TextureRect] = []
var _names: Array[Label] = []
var _name_plates: Array[Control] = []
var _continue: Control
var _typing: Tween
var _lines: Array[MFarmDialogueLine] = []
var _index := -1

func _ready() -> void:
	add_to_group(&"mfarm_dialogue_box")
	process_mode = Node.PROCESS_MODE_ALWAYS
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = PANEL_SIZE
	position = Vector2((640 - PANEL_SIZE.x) * 0.5, 180 + 40 - PANEL_SIZE.y * 0.5)
	visible = false
	var box := MFarmUiArt.panel("ui_dialogue", Vector2(180, 40))
	MFarmUiArt.place(self, box, Vector2(5, 24))
	_text = MFarmUiArt.label("", 8, TEXT_COLOR)
	_text.autowrap_mode = TextServer.AUTOWRAP_ARBITRARY
	_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_text.size = Vector2(135, 36)
	MFarmUiArt.place(box, _text, Vector2(22.5, 2))
	for left: bool in [true, false]:
		var face := MFarmUiArt.image(null, Vector2(64, 64))
		MFarmUiArt.place(self, face, Vector2(-31 if left else 157, 0))
		var plate := MFarmUiArt.panel("ui_coin_bg", Vector2(40, 12))
		plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
		MFarmUiArt.place(face, plate, Vector2(12, 46))
		var speaker := MFarmUiArt.label("", 8, Color.WHITE)
		speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		speaker.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		speaker.size = Vector2(40, 12)
		plate.add_child(speaker)
		_faces.append(face)
		_name_plates.append(plate)
		_names.append(speaker)
	# The old box held three Chinese words; English needs it wider.
	_continue = MFarmUiArt.panel("ui_paper_02", Vector2(120, 20))
	_continue.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var hint := MFarmUiArt.label("Press Space to continue", 8, TEXT_COLOR)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint.size = Vector2(120, 20)
	_continue.add_child(hint)
	MFarmUiArt.place(self, _continue, Vector2(35, 67))

func is_talking() -> bool:
	return _index >= 0

## Shows `lines` one after another; `finished` follows the last.
func play(lines: Array[MFarmDialogueLine]) -> void:
	if lines.is_empty() or is_talking():
		return
	_lines = lines.duplicate()
	_index = -1
	InputLock.lock(LOCK, true, self)
	visible = true
	_next()

func _next() -> void:
	_index += 1
	if _index >= _lines.size():
		_end()
		return
	var line := _lines[_index]
	var has_face := line.portrait != null or not line.speaker.is_empty()
	for side: int in 2:
		var shown := has_face and line.on_left == (side == 0)
		_faces[side].visible = shown
		_faces[side].texture = line.portrait
		_name_plates[side].visible = shown and not line.speaker.is_empty()
		_names[side].text = tr(line.speaker)
	_continue.visible = false
	_text.text = tr(line.text)
	_text.visible_ratio = 0.0
	if _typing != null and _typing.is_valid():
		_typing.kill()
	_typing = create_tween()
	_typing.tween_property(_text, ^"visible_ratio", 1.0, TYPE_SECONDS)
	_typing.finished.connect(func() -> void: _continue.visible = true)

## Ends the conversation at once; `finished` follows.
func stop() -> void:
	if is_talking():
		_end()

func _end() -> void:
	visible = false
	_index = -1
	_lines.clear()
	InputLock.unlock(LOCK)
	finished.emit()

func _unhandled_input(event: InputEvent) -> void:
	if not is_talking():
		return
	var advance := event.is_action_pressed(&"interact") or event.is_action_pressed(&"use_item")
	if not advance:
		return
	get_viewport().set_input_as_handled()
	if _typing != null and _typing.is_running():
		_typing.custom_step(TYPE_SECONDS)
	else:
		_next()
