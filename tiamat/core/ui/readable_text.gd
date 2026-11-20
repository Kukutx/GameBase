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
