class_name MenuEntry
extends PanelContainer

## A read-only entry of a menu's list (a tip, an achievement), a label a line,
## with an icon before them when it has one (`set_icon()`) and a bar under
## them when it shows how far something is (`add_bar()`).
## The keys and a gamepad move the focus through the entries as through
## buttons, so a list longer than its menu scrolls to the one in focus
## (`ScrollContainer.follow_focus`), which shows the focus as a button does;
## a drag on it still scrolls the list.

## The side of an entry's icon.
const ICON_SIZE := 24.0
## A bar's height, and its colours: what is left, and what is filled.
const BAR_HEIGHT := 4.0
const BAR_BACK := Color(1.0, 1.0, 1.0, 0.14)
const BAR_FILL := Color(0.55, 0.8, 0.64)

var _row: HBoxContainer
var _icon: TextureRect
var _lines: VBoxContainer

func _init() -> void:
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_PASS
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row = HBoxContainer.new()
	_row.name = "Row"
	_row.add_theme_constant_override(&"separation", 6)
	add_child(_row)
	_lines = VBoxContainer.new()
	_lines.name = "Lines"
	_lines.add_theme_constant_override(&"separation", 1)
	_lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_row.add_child(_lines)
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

## Adds a bar under the lines filled to `value` of `maximum`, and returns it.
func add_bar(value: float, maximum: float) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.max_value = maxf(maximum, 1.0)
	bar.value = clampf(value, 0.0, bar.max_value)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, BAR_HEIGHT)
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_theme_stylebox_override(&"background", _bar_style(BAR_BACK))
	bar.add_theme_stylebox_override(&"fill", _bar_style(BAR_FILL))
	_lines.add_child(bar)
	return bar

## The bar the entry shows, or null.
func get_bar() -> ProgressBar:
	for child: Node in _lines.get_children():
		if child is ProgressBar:
			return child
	return null

## Shows `texture` before the lines, at `ICON_SIZE`; null takes the icon away.
func set_icon(texture: Texture2D) -> void:
	if texture == null:
		if _icon != null:
			_icon.queue_free()
			_icon = null
		return
	if _icon == null:
		_icon = TextureRect.new()
		_icon.name = "Icon"
		_icon.custom_minimum_size = Vector2(ICON_SIZE, ICON_SIZE)
		_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_row.add_child(_icon)
		_row.move_child(_icon, 0)
	_icon.texture = texture

## The icon the entry shows, or null.
func get_icon() -> Texture2D:
	return _icon.texture if _icon != null else null

## The entry's lines, as its labels show them.
func get_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	for line: Node in _lines.get_children():
		if line is Label:
			lines.append((line as Label).text)
	return lines

func _bar_style(colour: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = colour
	style.set_corner_radius_all(2)
	return style

func _draw() -> void:
	if has_focus():
		draw_style_box(get_theme_stylebox(&"focus", &"Button"), Rect2(Vector2.ZERO, size))
