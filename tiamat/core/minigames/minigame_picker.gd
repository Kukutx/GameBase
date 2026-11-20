class_name MiniGamePicker
extends MenuLayer

## The list a station that offers several minigames opens
## (`MiniGameStation.choices`): a campaign's battles, an arcade's cabinets.
## Each is a button with its name (`MiniGameDefinition.display_name`), marked
## once the player won it in this save, and lines under it: its description
## and the player's best score (`score_name`), or, while its condition does
## not hold, what it needs, the button then locked. The keys, a gamepad and
## a tap pick one; `ui_cancel` or Back closes the list, and `picked` tells
## which the player picked, or none.

## The list closed; `minigame_id` is the minigame the player picked, or &"".
signal picked(minigame_id: StringName)

## The picker's name in `GameEvents.menu_opened` and `menu_closed`.
const MENU_ID := &"minigame_picker"
## The colour of the line under a minigame's name.
const NOTE_COLOR := Color(0.78, 0.78, 0.84)

@onready var _title: Label = %Title
@onready var _choices: ScrollContainer = %Choices
@onready var _list: VBoxContainer = %List
@onready var _back: Button = %Back

var _picked := &""

func _init() -> void:
	super(MENU_ID)

func _ready() -> void:
	_back.pressed.connect(close)
	closed.connect(func() -> void: picked.emit(_picked))
	# Its small print reads on a phone, in a narrow view as in a wide one.
	ReadableText.raise(self)

## Lists `choices` (minigame ids; unknown ones are left out) under `title`
## ("Choose" when empty) and shows the list, the focus on the first one the
## player can pick.
func open(choices: Array[StringName], title := "") -> void:
	_picked = &""
	_title.text = title if not title.is_empty() else tr("Choose")
	_fill(choices)
	show_menu()
	_choices.scroll_vertical = 0
	MenuLayer.focus(_first_open())

## The buttons of the minigames listed, in order.
func get_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for choice: Node in _list.get_children():
		var button := choice.get_node_or_null(^"Button") as Button
		if button != null:
			buttons.append(button)
	return buttons

## The line under the button of minigame `minigame_id`, or "" when it has none.
func get_note(minigame_id: StringName) -> String:
	var note := _list.get_node_or_null(NodePath("%s/Note" % minigame_id)) as Label
	return note.text if note != null else ""

## The text a minigame's button shows: its name, marked once won.
static func button_text(definition: MiniGameDefinition) -> String:
	var name: String = TranslationServer.translate(definition.display_name) if not definition.display_name.is_empty() else String(definition.id)
	return TranslationServer.translate("%s (Won)") % name if definition.get_wins() > 0 else name

## The line under it: its description and the player's best score, or what it
## needs while it is locked.
static func note_text(definition: MiniGameDefinition) -> String:
	if not definition.is_open():
		var needs := definition.get_requirements()
		return TranslationServer.translate("Locked: %s") % ", ".join(needs) if not needs.is_empty() else TranslationServer.translate("Locked")
	var lines := PackedStringArray()
	if not definition.description.is_empty():
		lines.append(TranslationServer.translate(definition.description))
	if not definition.score_name.is_empty() and definition.get_best_score() > 0:
		lines.append(TranslationServer.translate("Best %s: %d") % [TranslationServer.translate(definition.score_name), definition.get_best_score()])
	return "\n".join(lines)

func _fill(choices: Array[StringName]) -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for minigame_id: StringName in choices:
		var definition := MiniGameDefinition.find(minigame_id)
		if definition == null:
			continue
		# The button and the line under it, kept together, apart from the next.
		var choice := VBoxContainer.new()
		choice.name = String(minigame_id)
		choice.add_theme_constant_override(&"separation", 2)
		_list.add_child(choice)
		var button := MenuLayer.list_button(button_text(definition))
		button.name = "Button"
		# Its text is translated already.
		button.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		button.disabled = not definition.is_open()
		button.pressed.connect(_pick.bind(minigame_id))
		choice.add_child(button)
		var note := note_text(definition)
		if note.is_empty():
			continue
		var label := Label.new()
		label.name = "Note"
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.text = note
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override(&"font_color", NOTE_COLOR)
		choice.add_child(label)
	ReadableText.raise(_list)

func _first_open() -> Control:
	for button: Button in get_buttons():
		if not button.disabled:
			return button
	var buttons := get_buttons()
	return buttons[0] if not buttons.is_empty() else _back

func _pick(minigame_id: StringName) -> void:
	_picked = minigame_id
	close()
