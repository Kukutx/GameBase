class_name HotbarLine
extends HudLine

## The hotbar on the HUD: each slot's item, how many the inventory holds of
## what is not a tool, and which slot is in hand (`HotbarService.get_text()`),
## underlined.
## A click or a tap on a slot's part of the line picks that slot, so a player
## on a phone reaches any slot at once instead of stepping through them; the
## press goes no further (it uses no tool). A press beside the slots, or while
## the player cannot act (`InputLock`), passes on to the game.

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	super._ready()

func _watch() -> void:
	watch(Hotbar.changed)
	watch(Hotbar.selected_slot_changed)
	watch(InventoryState.changed)

func _get_parts() -> PackedStringArray:
	return PackedStringArray([Hotbar.get_text()])

## The slot whose part of the line is at `x`, in the line's own coordinates,
## or -1 beside every part. A part reaches halfway into the space on each side
## of it, so a tap between two slots picks the nearer.
func get_slot_at(x: float) -> int:
	var spans := _spans()
	for index: int in spans.size():
		var span := spans[index]
		var before := (span.y - spans[index - 1].z) / 2.0 if index > 0 else 0.0
		var after := (spans[index + 1].y - span.z) / 2.0 if index + 1 < spans.size() else 0.0
		if x >= span.y - before and x < span.z + after:
			return int(span.x)
	return -1

## Where the slot in hand's part of the line runs, from its left to its right
## (`Vector2(left, right)`, in the line's own coordinates), which the line
## underlines; `Vector2.ZERO` while that slot is empty.
func get_selected_span() -> Vector2:
	for span: Vector3 in _spans():
		if int(span.x) == Hotbar.selected_slot:
			return Vector2(span.y, span.z)
	return Vector2.ZERO

func _draw() -> void:
	var span := get_selected_span()
	if span == Vector2.ZERO:
		return
	var font_size := get_theme_font_size(&"font_size")
	var line_height := get_theme_font(&"font").get_height(font_size)
	var top := get_theme_stylebox(&"normal").get_margin(SIDE_TOP)
	match vertical_alignment:
		VERTICAL_ALIGNMENT_CENTER:
			top = (size.y - line_height) / 2.0
		VERTICAL_ALIGNMENT_BOTTOM:
			top = size.y - line_height - get_theme_stylebox(&"normal").get_margin(SIDE_BOTTOM)
	var thickness := maxf(roundf(font_size / 6.0), 1.0)
	var bar := Rect2(span.x, top + line_height, span.y - span.x, thickness)
	draw_rect(bar.grow(1.0), ReadableText.OUTLINE_COLOR)
	draw_rect(bar, get_theme_color(&"font_color"))

# Each filled slot's part of the line as (slot, left, right), in the line's
# own coordinates, laid out as the line draws its text: each edge is measured
# as the width of the whole line's text up to it, so the spaces and the
# letters' spacing come out as the line draws them.
func _spans() -> Array[Vector3]:
	var font := get_theme_font(&"font")
	var font_size := get_theme_font_size(&"font_size")
	var parts := Hotbar.get_slot_parts()
	var texts := PackedStringArray()
	for part: Dictionary in parts:
		texts.append(String(part["text"]))
	var whole := HotbarService.PART_SEPARATOR.join(texts)
	var total := font.get_string_size(whole, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var style := get_theme_stylebox(&"normal")
	var room := size.x - style.get_margin(SIDE_LEFT) - style.get_margin(SIDE_RIGHT)
	var left := style.get_margin(SIDE_LEFT)
	match horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			left += maxf(room - total, 0.0) / 2.0
		HORIZONTAL_ALIGNMENT_RIGHT:
			left += maxf(room - total, 0.0)
	var spans: Array[Vector3] = []
	var at := 0
	for index: int in parts.size():
		var from := left + _width_of(whole, at, font, font_size)
		at += texts[index].length()
		spans.append(Vector3(int(parts[index]["slot"]), from, left + _width_of(whole, at, font, font_size)))
		at += HotbarService.PART_SEPARATOR.length()
	return spans

# How wide the first `count` characters of `text` draw.
static func _width_of(text: String, count: int, font: Font, font_size: int) -> float:
	return font.get_string_size(text.left(count), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x if count > 0 else 0.0

func _gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT or InputLock.is_locked():
		return
	var slot := get_slot_at(press.position.x)
	if slot >= 0:
		Hotbar.select_slot(slot)
		accept_event()
