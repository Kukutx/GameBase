class_name TipsMenu
extends CanvasLayer

## The tips the player has seen (`HintData`), to read again from the pause
## menu: a hint shows once, on a status line, and may pass before the player
## has read it. Each tip names its controls as the device in use performs
## them, and again when the player picks up another. `ui_cancel` or Back
## closes it.

signal closed

## The tips menu's name in `GameEvents.menu_opened` and `menu_closed`.
const MENU_ID := &"tips_menu"

@onready var _tips: ScrollContainer = %Tips
@onready var _list: VBoxContainer = %List
@onready var _back: Button = %Back

## The hints the player has seen, in any save, in the order of their ids.
static func seen_hints() -> Array[HintData]:
	var seen: Array[HintData] = []
	for entry: Variant in ContentRegistry.active.get_entries(HintData.KIND):
		var hint := entry as HintData
		if hint != null and GameProfile.get_bool(HintData.get_shown_flag(hint.id)):
			seen.append(hint)
	seen.sort_custom(func(a: HintData, b: HintData) -> bool: return String(a.id) < String(b.id))
	return seen

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	_back.pressed.connect(close)
	InputPrompts.input_method_changed.connect(_on_input_method_changed.unbind(1))
	# Its small print reads on a phone, in a narrow view as in a wide one.
	ReadableText.raise(self)

## Shows the tips seen so far.
func open() -> void:
	_fill()
	var opened := not visible
	visible = true
	_tips.scroll_vertical = 0
	MenuLayer.focus(_back)
	if opened:
		GameEvents.menu_opened.emit(MENU_ID)

func close() -> void:
	if not visible:
		return
	visible = false
	GameEvents.menu_closed.emit(MENU_ID)
	closed.emit()

## The texts the menu shows, one a tip.
func get_texts() -> PackedStringArray:
	var texts := PackedStringArray()
	for label: Node in _list.get_children():
		texts.append((label as Label).text)
	return texts

func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()

func _fill() -> void:
	for child: Node in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	for hint: HintData in seen_hints():
		var label := Label.new()
		# The hint translates itself and names its controls.
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		label.text = hint.get_message()
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_list.add_child(label)
	ReadableText.raise(_list)

func _on_input_method_changed() -> void:
	if visible:
		_fill()
