class_name ChoiceMenu
extends MenuLayer

## A list the player picks one choice from, over the paused world: a station's
## minigames (`MiniGameStation.choices`), an elevator's floors, the depth a
## run starts at. Each choice (`Choice`) is a button with its text and the
## lines under it (its note), and may be locked, its button then disabled and
## its note saying what it needs. Lines above the list (its body) may say
## what the choice is about. The keys, a gamepad and a tap pick one;
## `ui_cancel` or Back closes the list, and `picked` tells which the player
## picked, or none.
##
## Whatever offers the player a choice asks with
## `var id := await ChoiceMenu.ask(self, choices, title)`, which adds the menu
## to it the first time (`of()` finds it again) and gives the id of the choice
## picked, or &"" when the player closed the list. Whatever only tells the
## player something (a run's report) shows it with `ChoiceMenu.tell(self,
## title, lines)`, a body and one choice, OK.

## The list closed; `choice_id` is the choice the player picked, or &"".
signal picked(choice_id: StringName)

## The menu's name in `GameEvents.menu_opened` and `menu_closed`.
const MENU_ID := &"choice_menu"
## The name of the menu `ask()` adds to the node that asks.
const NODE_NAME := &"ChoiceMenu"
## The colour of the lines under a choice.
const NOTE_COLOR := Color(0.78, 0.78, 0.84)
const SCENE_PATH := "res://tiamat/core/ui/choice_menu.tscn"
## The id of the one choice `tell()` lists, OK.
const OK_ID := &"ok"

## One choice of the list: its id, its text and the lines under it as the
## player reads them (translated already), and whether the player can pick it.
class Choice:
	extends RefCounted

	var id: StringName
	var text: String
	var note: String
	var enabled: bool

	func _init(choice_id: StringName, choice_text: String, choice_note := "", choice_enabled := true) -> void:
		id = choice_id
		text = choice_text
		note = choice_note
		enabled = choice_enabled

@onready var _title: Label = %Title
@onready var _body: Label = %Body
@onready var _choices: ScrollContainer = %Choices
@onready var _list: VBoxContainer = %List
@onready var _back: Button = %Back

var _picked := &""
var _buttons: Dictionary[StringName, Button] = {}
var _notes: Dictionary[StringName, Label] = {}

func _init() -> void:
	super(MENU_ID)

func _ready() -> void:
	_back.pressed.connect(close)
	# Its text is translated already.
	_body.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	closed.connect(func() -> void: picked.emit(_picked))
	# Its small print reads on a phone, in a narrow view as in a wide one.
	ReadableText.raise(self)

## Shows `choices` under `title` (translated as a key; "Choose" when empty)
## and `body` (translated already) in a menu of `host`'s, added to it the
## first time, and gives the id of the choice the player picks, or &"" when
## they close the list. The focus starts on `focus_id`, or on the first choice
## the player can pick.
static func ask(host: Node, choices: Array[Choice], title := "", focus_id := &"", body := "") -> StringName:
	var menu := _of_or_new(host)
	menu.open(choices, title, focus_id, body)
	var choice_id: StringName = await menu.picked
	return choice_id

## Tells the player `lines` (translated already) under `title` (translated as
## a key) in a menu of `host`'s, with one choice, OK, and gives the menu:
## `await menu.picked` waits until the player read on.
static func tell(host: Node, title: String, lines: PackedStringArray) -> ChoiceMenu:
	var menu := _of_or_new(host)
	var choices: Array[Choice] = [Choice.new(OK_ID, TranslationServer.translate("OK"))]
	menu.open(choices, title, OK_ID, "\n".join(lines))
	return menu

## The menu `ask()` added to `host`, or null before it first asked.
static func of(host: Node) -> ChoiceMenu:
	return host.get_node_or_null(NodePath(NODE_NAME)) as ChoiceMenu

## Lists `choices` under `title` and `body` and shows the list, the focus on
## `focus_id` when the player can pick it, else on the first choice they can.
func open(choices: Array[Choice], title := "", focus_id := &"", body := "") -> void:
	_picked = &""
	_title.text = title if not title.is_empty() else tr("Choose")
	_body.text = body
	_body.visible = not body.is_empty()
	_fill(choices)
	show_menu()
	_choices.scroll_vertical = 0
	var button: Button = _buttons.get(focus_id)
	MenuLayer.focus(button if button != null and not button.disabled else _first_open())

## The lines above the choices, or "" when there are none.
func get_body() -> String:
	return _body.text

## The buttons of the choices listed, in order.
func get_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	buttons.assign(_buttons.values())
	return buttons

## The ids of the choices listed, in order.
func get_choice_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	ids.assign(_buttons.keys())
	return ids

## The button of choice `choice_id`, or null when the list holds none.
func get_button(choice_id: StringName) -> Button:
	return _buttons.get(choice_id)

## The lines under choice `choice_id`, or "" when it has none.
func get_note(choice_id: StringName) -> String:
	var note: Label = _notes.get(choice_id)
	return note.text if note != null else ""

## Picks `choice_id` as the player does, when the list holds it and the player
## can pick it; true when it did.
func choose(choice_id: StringName) -> bool:
	var button: Button = _buttons.get(choice_id)
	if button == null or button.disabled or not is_open():
		return false
	button.pressed.emit()
	return true

static func _of_or_new(host: Node) -> ChoiceMenu:
	var menu := of(host)
	if menu == null:
		menu = (load(SCENE_PATH) as PackedScene).instantiate() as ChoiceMenu
		menu.name = NODE_NAME
		host.add_child(menu)
	return menu

func _fill(choices: Array[Choice]) -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	_buttons.clear()
	_notes.clear()
	for choice: Choice in choices:
		if _buttons.has(choice.id):
			continue
		# The button and the lines under it, kept together, apart from the next.
		var row := VBoxContainer.new()
		row.add_theme_constant_override(&"separation", 2)
		_list.add_child(row)
		var button := MenuLayer.list_button(choice.text)
		# Its text is translated already.
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.disabled = not choice.enabled
		button.pressed.connect(_pick.bind(choice.id))
		row.add_child(button)
		_buttons[choice.id] = button
		if choice.note.is_empty():
			continue
		var label := Label.new()
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.text = choice.note
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override(&"font_color", NOTE_COLOR)
		row.add_child(label)
		_notes[choice.id] = label
	ReadableText.raise(_list)

func _first_open() -> Control:
	for button: Button in get_buttons():
		if not button.disabled:
			return button
	var buttons := get_buttons()
	return buttons[0] if not buttons.is_empty() else _back

func _pick(choice_id: StringName) -> void:
	_picked = choice_id
	close()
