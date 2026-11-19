class_name JianghuDeskWindow
extends Node

## How the game sits on the screen. On a desktop that can show a window with
## see-through pixels the hero lives on the desktop itself ("pet mode"): a
## borderless, see-through window that stays on top, down by the taskbar,
## through which clicks pass everywhere but on the hero and the open panel.
## Otherwise (the web, a phone, or the player's choice) it is an ordinary
## window with the landscape behind the hero.
##
## The choice and where the window stood are the player's device settings,
## kept in `PREFS_PATH` as JSON, not in the save.

signal mode_changed(pet_mode: bool)

const PREFS_PATH := "user://jianghu_window.json"
## The view's size; the window is this times the screen's scale.
const VIEW_SIZE := Vector2i(360, 540)
## How much of the window, in the view, stays above the bottom of the
## usable screen in pet mode: the hero stands on the taskbar.
const WINDOWED_SCALE := 1.5

var pet_mode := false
var _scale := 1.0
var _prefs: Dictionary = {}

## Whether this device can put the hero on the desktop.
static func is_supported() -> bool:
	return OS.has_feature("pc") and not OS.has_feature("web") \
		and DisplayServer.has_feature(DisplayServer.FEATURE_WINDOW_TRANSPARENCY)

func _ready() -> void:
	_prefs = _read_prefs()
	_scale = _screen_scale()
	var wanted := bool(_prefs.get("pet_mode", true))
	set_pet_mode(wanted and is_supported(), true)

func set_pet_mode(value: bool, force := false) -> void:
	value = value and is_supported()
	if value == pet_mode and not force:
		return
	pet_mode = value
	var window := get_window()
	get_viewport().transparent_bg = pet_mode
	# In a window of any shape the landscape fills it; on the desktop the
	# window is the view's own shape. A headless run has no window to shape.
	if DisplayServer.get_name() != "headless":
		window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP if pet_mode else Window.CONTENT_SCALE_ASPECT_EXPAND
	if is_supported():
		window.borderless = pet_mode
		window.transparent = pet_mode
		window.always_on_top = pet_mode
		if pet_mode:
			window.size = Vector2i(Vector2(VIEW_SIZE) * _scale)
			window.position = _pet_position(window.size)
		else:
			window.mouse_passthrough_polygon = PackedVector2Array()
			window.size = Vector2i(Vector2(VIEW_SIZE) * _scale * WINDOWED_SCALE)
			window.move_to_center()
	_prefs["pet_mode"] = pet_mode
	_write_prefs()
	mode_changed.emit(pet_mode)

## Moves the window by `delta` pixels of the screen, kept on the screen it is on.
func move_window(delta: Vector2) -> void:
	if not pet_mode:
		return
	var window := get_window()
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	var target := Vector2i(Vector2(window.position) + delta)
	target.x = clampi(target.x, usable.position.x - window.size.x / 3, usable.end.x - window.size.x * 2 / 3)
	target.y = clampi(target.y, usable.position.y - window.size.y / 2, usable.end.y - window.size.y)
	window.position = target

## Whether the window may walk `delta` screen pixels sideways without leaving
## the screen.
func can_walk(delta: float) -> bool:
	var window := get_window()
	var usable := DisplayServer.screen_get_usable_rect(window.current_screen)
	var x := window.position.x + int(delta)
	return x >= usable.position.x - window.size.x / 3 and x + window.size.x * 2 / 3 <= usable.end.x

## The pixels of the screen one pixel of the view takes.
func get_view_scale() -> float:
	var window := get_window()
	return float(window.size.x) / VIEW_SIZE.x if pet_mode else 1.0

## Clicks land only inside `rect`, in the view; everything else passes
## through to the desktop.
func set_clickable(rect: Rect2) -> void:
	if not pet_mode:
		return
	var to_window := get_viewport().get_final_transform()
	var area := to_window * rect
	get_window().mouse_passthrough_polygon = PackedVector2Array([
		area.position, Vector2(area.end.x, area.position.y), area.end, Vector2(area.position.x, area.end.y)])

## Remembers where the window stands, for the next start.
func remember_position() -> void:
	if not pet_mode:
		return
	var window := get_window()
	_prefs["x"] = window.position.x
	_prefs["y"] = window.position.y
	_write_prefs()

func _pet_position(window_size: Vector2i) -> Vector2i:
	var usable := DisplayServer.screen_get_usable_rect(get_window().current_screen)
	var fallback := Vector2i(usable.end.x - window_size.x - 24, usable.end.y - window_size.y)
	var x: Variant = SaveValues.whole_number(_prefs.get("x"))
	var y: Variant = SaveValues.whole_number(_prefs.get("y"))
	if x == null or y == null:
		return fallback
	var saved := Rect2i(Vector2i(int(x), int(y)), window_size)
	# Only where the hero would still be seen on this screen.
	return saved.position if usable.intersects(saved.grow(-window_size.x / 3)) else fallback

static func _screen_scale() -> float:
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var by_height := float(usable.size.y) / 1000.0 if usable.size.y > 0 else 1.0
	return clampf(snappedf(maxf(DisplayServer.screen_get_scale(screen), by_height), 0.25), 1.0, 3.0)

func _read_prefs() -> Dictionary:
	if not FileAccess.file_exists(PREFS_PATH):
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(PREFS_PATH)) != OK or not json.data is Dictionary:
		return {}
	return json.data

func _write_prefs() -> void:
	var file := FileAccess.open(PREFS_PATH, FileAccess.WRITE)
	if file == null or not file.store_string(JSON.stringify(_prefs)):
		push_warning("Could not write %s" % PREFS_PATH)
