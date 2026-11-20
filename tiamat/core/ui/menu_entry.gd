class_name MenuEntry
extends PanelContainer

## A read-only entry of a menu's list (a tip, an achievement), a label a line.
## The keys and a gamepad move the focus through the entries as through
## buttons, so a list longer than its menu scrolls to the one in focus
## (`ScrollContainer.follow_focus`), which shows the focus as a button does;
## a drag on it still scrolls the list.

var _lines: VBoxContainer

func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lines = VBoxContainer.new()
	_lines.name = "Lines"
	_lines.add_theme_constant_override(&"separation", 1)
	add_child(_lines)
	var room := StyleBoxEmpty.new()
	room.set_content_margin_all(2.0)
	add_theme_stylebox_override(&"panel", room)
	focus_entered.connect(queue_redraw)
	focus_exited.connect(queue_redraw)

## Adds a line under the others and returns its label, wrapped at the entry's
## width; `translate` false for text that is translated already (a hint's).
func add_line(text: String, translate := true) -> Label:
	var label := Label.new()
	if not translate:
		label.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lines.add_child(label)
	return label

## The entry's lines, as its labels show them.
func get_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for label: Node in _lines.get_children():
		lines.append((label as Label).text)
	return lines

func _draw() -> void:
	if has_focus():
		draw_style_box(get_theme_stylebox(&"focus", &"Button"), Rect2(Vector2.ZERO, size))
