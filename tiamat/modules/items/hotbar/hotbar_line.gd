class_name HotbarLine
extends HudLine

## The hotbar on the HUD: each slot's item, how many the inventory holds of
## what is not a tool, and which slot is in hand (`HotbarService.get_text()`).
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
	var font := get_theme_font(&"font")
	var font_size := get_theme_font_size(&"font_size")
	var parts := Hotbar.get_slot_parts()
	var widths: Array[float] = []
	var total := 0.0
	for part: Dictionary in parts:
		widths.append(font.get_string_size(String(part["text"]), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
		total += widths[-1]
	var gap := font.get_string_size(HotbarService.PART_SEPARATOR, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	total += gap * maxi(parts.size() - 1, 0)
	var style := get_theme_stylebox(&"normal")
	var room := size.x - style.get_margin(SIDE_LEFT) - style.get_margin(SIDE_RIGHT)
	var left := style.get_margin(SIDE_LEFT)
	match horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			left += maxf(room - total, 0.0) / 2.0
		HORIZONTAL_ALIGNMENT_RIGHT:
			left += maxf(room - total, 0.0)
	for index: int in parts.size():
		var right := left + widths[index]
		if x >= left - gap / 2.0 and x < right + gap / 2.0:
			return int(parts[index]["slot"])
		left = right + gap
	return -1

func _gui_input(event: InputEvent) -> void:
	var press := event as InputEventMouseButton
	if press == null or not press.pressed or press.button_index != MOUSE_BUTTON_LEFT or InputLock.is_locked():
		return
	var slot := get_slot_at(press.position.x)
	if slot >= 0:
		Hotbar.select_slot(slot)
		accept_event()
