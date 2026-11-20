class_name ReadableText
extends RefCounted

## Text a player reads on a phone without strain: at least Android's smallest
## text, 12 sp (`MIN_TEXT_MM`), on a small phone, whose short side shows the
## short side of the game's view across `PHONE_SHORT_MM`. A view 270 pixels
## high needs text 8 pixels high; a phone held upright that shows a view 360
## pixels wide needs 11.
##
## The core's menus raise their smaller text to it once they are ready
## (`raise()`), so a menu laid out for a wide view still reads in a game that
## shows it in a narrow one; the test of every game's screens holds each text
## to it in the view the game shows a phone (`test_screens_fit.gd`).

## The colour of the outline `outline()` draws around text over the world.
const OUTLINE_COLOR := Color(0.02, 0.02, 0.03, 0.75)
## The colour of the band `back()` draws behind a message over the world.
const BAND_COLOR := Color(0.02, 0.02, 0.03, 0.7)
## The height of Android's smallest text, 12 sp, in millimetres.
const MIN_TEXT_MM := 1.9
## The short side of a small phone's screen, in millimetres.
const PHONE_SHORT_MM := 65.0
## The font sizes of a rich text label, each raised alike.
const RICH_SIZES: Array[StringName] = [&"normal_font_size", &"bold_font_size", &"italics_font_size",
	&"bold_italics_font_size", &"mono_font_size"]

## The smallest font size, in pixels of a view of `view_size`, that a phone
## shows large enough to read.
static func min_font_size(view_size: Vector2) -> int:
	var short := minf(view_size.x, view_size.y)
	# A hair under: 270 pixels need 7.89, read as 8, not 9.
	return maxi(ceili(short * MIN_TEXT_MM / PHONE_SHORT_MM - 0.01), 1)

## The size `control` draws its text at, in pixels of its view (its font size
## times how much larger its canvas draws it); 0 for a control that draws no
## text.
static func font_size_of(control: Control) -> int:
	var name := _size_name(control)
	if name == &"":
		return 0
	return roundi(control.get_theme_font_size(name) * _scale_of(control))

## Has every control under `root` (and `root`) that draws text smaller than its
## view reads on a phone (`min_font_size()`) draw it at that size; the rest
## keep theirs.
static func raise(root: Node) -> void:
	var controls: Array[Node] = root.find_children("*", "Control", true, false)
	if root is Control:
		controls.append(root)
	for node: Node in controls:
		var control := node as Control
		var name := _size_name(control)
		if name == &"" or not control.is_inside_tree():
			continue
		var scale := _scale_of(control)
		var wanted := ceili(min_font_size(control.get_viewport().get_visible_rect().size) / scale - 0.01)
		var names: Array[StringName] = [name]
		if control is RichTextLabel:
			names = RICH_SIZES
		for each: StringName in names:
			if control.get_theme_font_size(each) < wanted:
				control.add_theme_font_size_override(each, wanted)

## Has `label` draw its line of text at `size`, or smaller as far as its text
## needs to fit the label's width, but never below what its view reads on a
## phone (`min_font_size()`); a text still too long past that is cut at the
## edge with an ellipsis rather than run over what stands beside it. A HUD
## line that grows with what it tells (money, a deep floor) keeps clear of its
## neighbour this way (`HudLine.shrinks_to_fit`).
static func fit_width(label: Label, size: int) -> void:
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	var smallest := size
	if label.is_inside_tree():
		var readable := ceili(min_font_size(label.get_viewport().get_visible_rect().size) / _scale_of(label) - 0.01)
		smallest = mini(size, readable)
	var font := label.get_theme_font(&"font")
	var fitted := size
	while fitted > smallest and font.get_string_size(label.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fitted).x > label.size.x:
		fitted -= 1
	label.add_theme_font_size_override(&"font_size", fitted)

## Draws a dark outline around `label`'s text, a quarter of its font size
## thick and at least 2 pixels, so a line over the world (the HUD's, its
## messages) reads on bright ground as well as on dark. A label whose scene
## or theme gives it an outline keeps that one.
static func outline(label: Label) -> void:
	if label.get_theme_constant(&"outline_size") > 0:
		return
	label.add_theme_constant_override(&"outline_size", maxi(roundi(label.get_theme_font_size(&"font_size") / 4.0), 2))
	label.add_theme_color_override(&"font_outline_color", OUTLINE_COLOR)

## Draws a dark band behind `label`'s text while it has any, a little wider
## and taller than the text, so a message over the world (a hint, a toast)
## stands apart from the names and signs of the world under it. A label
## backed once stays so.
static func back(label: Label) -> void:
	if label.has_meta(&"band"):
		return
	var band := _Band.new()
	label.add_child(band, false, Node.INTERNAL_MODE_FRONT)
	label.set_meta(&"band", band)
	# It draws again whenever the label does: its text, size or font changed.
	label.draw.connect(band.queue_redraw)

## Where `label` draws its text, in its own coordinates, as its alignment
## places it; an empty rect while it shows none.
static func text_rect(label: Label) -> Rect2:
	var shown := label.atr(label.text) if label.can_auto_translate() else label.text
	if shown.is_empty():
		return Rect2()
	var font := label.get_theme_font(&"font")
	var font_size := label.get_theme_font_size(&"font_size")
	var box := label.get_theme_stylebox(&"normal")
	var room := label.size - box.get_minimum_size()
	var wraps := label.autowrap_mode != TextServer.AUTOWRAP_OFF
	var size := font.get_multiline_string_size(shown, label.horizontal_alignment, room.x if wraps else -1.0, font_size)
	if wraps or label.clip_text or label.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING:
		size.x = minf(size.x, room.x)
	var left := box.get_margin(SIDE_LEFT)
	match label.horizontal_alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			left += (room.x - size.x) / 2.0
		HORIZONTAL_ALIGNMENT_RIGHT:
			left += room.x - size.x
	var top := box.get_margin(SIDE_TOP)
	match label.vertical_alignment:
		VERTICAL_ALIGNMENT_CENTER:
			top += (room.y - size.y) / 2.0
		VERTICAL_ALIGNMENT_BOTTOM:
			top += room.y - size.y
	return Rect2(left, top, size.x, size.y)

# The theme font size `control` draws its text with, or empty for one that
# draws none.
static func _size_name(control: Control) -> StringName:
	if control is RichTextLabel:
		return &"normal_font_size"
	if control is Label or control is Button or control is LineEdit or control is TextEdit or control is ItemList \
			or control is Tree or control is TabBar or control is SpinBox:
		return &"font_size"
	return &""

static func _scale_of(control: Control) -> float:
	var scale := control.get_global_transform_with_canvas().get_scale().y if control.is_inside_tree() else 1.0
	return scale if scale > 0.0 else 1.0

# The band `back()` draws behind its label's text, under it.
class _Band extends Control:
	var _box := StyleBoxFlat.new()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		show_behind_parent = true
		_box.bg_color = ReadableText.BAND_COLOR

	func _draw() -> void:
		var label := get_parent() as Label
		var rect := ReadableText.text_rect(label) if label != null else Rect2()
		if not rect.has_area():
			return
		var font_size := label.get_theme_font_size(&"font_size")
		_box.set_corner_radius_all(roundi(font_size * 0.4))
		var across := font_size * 0.6
		var down := font_size * 0.15
		draw_style_box(_box, rect.grow_individual(across, down, across, down))
