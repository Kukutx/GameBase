class_name HudLine
extends Label

## A line of the HUD that tells the player something that keeps changing: the
## parts `_get_parts()` gives, each already in the player's language, joined
## by `separator`. It is told again once at the end of a frame in which a
## signal it watches fired (`watch()`, in `_watch()`), the language changed or
## a scene opened. `PlaceLine` and `ControlsLine` are the core's; a game shows
## a line of its own, such as health and money or the depth of a run, by
## extending one of them or this.

## What stands between two parts.
@export var separator := " · "
## Whether the line hides while it has nothing to tell.
@export var hides_when_empty := false
## Whether a text too long for the line's width shrinks to fit it, down to
## what a phone reads, and is cut past that (`ReadableText.fit_width()`),
## rather than run over the line beside it: for a line that grows with what it
## tells, such as the money or the place and the time.
@export var shrinks_to_fit := false
## Whether its text has a dark outline, to read over any ground
## (`ReadableText.outline()`).
@export var outlined := true

var _queued := false
# The font size the line draws at while its text fits.
var _full_font_size := 0

func _ready() -> void:
	if outlined:
		ReadableText.outline(self)
	if shrinks_to_fit:
		_full_font_size = get_theme_font_size(&"font_size")
		resized.connect(_fit)
	watch(GameSettings.locale_changed)
	watch(get_tree().scene_changed)
	_watch()
	# A part may read the current scene, which is set once the scene is in.
	_queue_refresh()

## Tells the line again at the end of the frame after `changed` fires.
func watch(changed: Signal) -> void:
	changed.connect(_on_watched)

## Tells the line now.
func refresh() -> void:
	if not is_inside_tree():
		return
	var parts := PackedStringArray()
	for part: String in _get_parts():
		if not part.is_empty():
			parts.append(part)
	text = separator.join(parts)
	if hides_when_empty:
		visible = not text.is_empty()
	_fit()

## The parts of the line; an empty one is left out.
func _get_parts() -> PackedStringArray:
	return PackedStringArray()

## Watches the signals the line follows; called once, as it enters the tree.
func _watch() -> void:
	pass

func _on_watched(..._values: Array) -> void:
	_queue_refresh()

func _queue_refresh() -> void:
	if _queued:
		return
	_queued = true
	_refresh_queued.call_deferred()

func _refresh_queued() -> void:
	_queued = false
	refresh()

func _fit() -> void:
	if shrinks_to_fit and _full_font_size > 0:
		ReadableText.fit_width(self, _full_font_size)
