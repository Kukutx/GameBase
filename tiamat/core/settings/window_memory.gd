class_name WindowMemory
extends RefCounted

## Where the game's window was: a computer opens the game where the player
## left it, at the size they gave it, and maximized if it was. `GameSettings`
## restores it as the game starts and remembers it as the game quits, in a
## file of its own beside the settings (`PATH`): the window is where the
## player left it, not a choice they made in the settings.
##
## A window whose top edge is on no screen any more (a screen unplugged)
## opens in the middle of the first screen, and none opens larger than the
## screen it opens on. A phone, a browser, a full screen and a run from the
## editor keep nothing, nor does a borderless window (a desktop pet's own).

const PATH := "user://window.json"
## How far below the middle of the window's top edge, in pixels, the point
## that must lie on a screen sits: the player can grab the window there.
const GRIP := 16

## Writes where the window is now to `path`, when it is kept.
static func remember(path := PATH) -> void:
	if not is_kept() or DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS):
		return
	var mode := DisplayServer.window_get_mode()
	if mode != DisplayServer.WINDOW_MODE_WINDOWED and mode != DisplayServer.WINDOW_MODE_MAXIMIZED:
		return
	var data := read(path)
	data["maximized"] = mode == DisplayServer.WINDOW_MODE_MAXIMIZED
	# A maximized window keeps the place it goes back to.
	if mode == DisplayServer.WINDOW_MODE_WINDOWED:
		var position := DisplayServer.window_get_position()
		var size := DisplayServer.window_get_size()
		data["rect"] = [position.x, position.y, size.x, size.y]
	JsonFile.write(path, data)

## Puts the window back where `path` says it was, when it is kept.
static func restore(path := PATH) -> void:
	if not is_kept():
		return
	var data := read(path)
	var screens: Array[Rect2i] = []
	for screen: int in DisplayServer.get_screen_count():
		screens.append(DisplayServer.screen_get_usable_rect(screen))
	var rect := place(rect_of(data), screens)
	if rect.has_area():
		DisplayServer.window_set_size(rect.size)
		DisplayServer.window_set_position(rect.position)
	if bool(data.get("maximized", false)):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_MAXIMIZED)

## Whether this game's window is one to keep: a window of its own on a
## computer.
static func is_kept() -> bool:
	return OS.has_feature("pc") and not OS.has_feature("web") and not OS.has_feature("editor") \
		and DisplayServer.get_name() != "headless"

## Where a window last at `saved` opens among the usable rects of the
## `screens`: where it was if the middle of its top edge is on one of them,
## else in the middle of the first; no larger than that screen. Empty when
## nothing was saved.
static func place(saved: Rect2i, screens: Array[Rect2i]) -> Rect2i:
	if not saved.has_area() or screens.is_empty():
		return Rect2i()
	var grip := Vector2i(saved.position.x + saved.size.x / 2, saved.position.y + mini(GRIP, saved.size.y / 2))
	for screen: Rect2i in screens:
		if screen.has_point(grip):
			return Rect2i(saved.position, saved.size.min(screen.size))
	var first := screens[0]
	var size := saved.size.min(first.size)
	return Rect2i(first.position + (first.size - size) / 2, size)

## What the file at `path` holds; empty when it holds nothing usable.
static func read(path := PATH) -> Dictionary:
	var data: Variant = JsonFile.read(path)
	return data if data is Dictionary else {}

## The window's rect in `data`; empty when it holds none.
static func rect_of(data: Dictionary) -> Rect2i:
	var values: Variant = data.get("rect")
	if not values is Array or (values as Array).size() != 4:
		return Rect2i()
	for value: Variant in values:
		if not (value is float or value is int):
			return Rect2i()
	var rect := Rect2i(int(values[0]), int(values[1]), int(values[2]), int(values[3]))
	return rect if rect.size.x > 0 and rect.size.y > 0 else Rect2i()
